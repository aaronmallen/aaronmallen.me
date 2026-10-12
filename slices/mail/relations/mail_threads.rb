# frozen_string_literal: true

module Mail
  module Relations
    class MailThreads < Blog::DB::Relation
      LETTER = %i[reply_to body].freeze

      schema :mail_threads, infer: true do
        associations do
          belongs_to :mail_account
          has_many :mail_messages
          has_many :mail_thread_tags
          has_many :tags, through: :mail_thread_tags, view: :in_name_order
        end
      end

      def marked_spam_before(time) = where { marked_spam_at < time }

      def matching(text) = containing(text, :subject, tag_names, letters)

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def tagged(name)
        return none if unmatchable?(name)

        where(id: mail_thread_tags.holding_every([name]).dataset)
      end

      def with_account
        named = mail_accounts.dataset.unordered.where(id: self[:mail_account_id].qualified).select(:name)

        select_append(ROM::SQL::Attribute[ROM::Types::String].meta(sql_expr: named).as(:account))
      end

      def with_letter
        first = sent.order(:received_at, :id).limit(1)

        select_append(*LETTER.map { ROM::SQL::Attribute[ROM::Types::String].meta(sql_expr: first.select(it)).as(it) })
      end

      def with_status(status) = where(status:)

      private

      def letters
        joined = sent.select(Sequel.function(:string_agg, Sequel.join(LETTER, " "), " "))

        Sequel.function(:coalesce, joined, "")
      end

      def sent = mail_messages.dataset.unordered.where(mail_thread_id: self[:id].qualified)

      def tag_names
        names = mail_thread_tags.join(:tag).where(mail_thread_id: self[:id].qualified).dataset.unordered
        joined = names.select(Sequel.function(:string_agg, Blog::DB::Plugins::Taggings::NAME, " "))

        Sequel.function(:coalesce, joined, "")
      end
    end
  end
end
