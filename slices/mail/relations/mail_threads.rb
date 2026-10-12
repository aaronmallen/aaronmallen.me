# frozen_string_literal: true

module Mail
  module Relations
    class MailThreads < Blog::DB::Relation
      FOLDERS = Blog::Types::MailFolder.values.to_h { [it, :"#{it}_folder"] }.freeze
      LETTER = %i[reply_to body].freeze
      PRIMARY = Sequel.|({ category: nil }, { category: Blog::Types::MailCategory["personal"] })
      SEARCHED = %i[reply_to body from_name].map { Sequel.function(:coalesce, it, "") }.freeze
      SPAM = Blog::Types::MessageStatus["spam"]

      schema :mail_threads, infer: true do
        associations do
          belongs_to :mail_account
          has_many :mail_messages, view: :oldest_first
          has_many :mail_thread_labels
          has_many :mail_labels, through: :mail_thread_labels, view: :in_name_order
          has_many :mail_thread_tags
          has_many :tags, through: :mail_thread_tags, view: :in_name_order
        end
      end

      def in_folder(folder) = __send__(FOLDERS.fetch(folder))

      def labeled(name)
        return none if unmatchable?(name)

        held = mail_thread_labels.join(:mail_label).where(Sequel[:mail_labels][:name] => name).dataset.unordered
        kept.where(Sequel.|({ id: held.select(:mail_thread_id) },
                            { id: mail_thread_tags.holding_every([name]).dataset }))
      end

      def marked_spam_before(time) = where { marked_spam_at < time }

      def matching(text) = containing(text, :subject, tag_names, letters)

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def with_account
        named = mail_accounts.dataset.unordered.where(id: self[:mail_account_id].qualified).select(:name)

        select_append(column(named, :account))
      end

      def with_letter = select_append(*LETTER.map { column(first_message.select(it), it) })

      def with_status(status) = where(status:)

      def with_summary
        select_append(
          column(first_message.select(Sequel.function(:coalesce, :from_name, :reply_to)), :sender),
          column(first_message.select(:reply_to), :reply_to),
          column(last_message.select(:body), :preview),
          column(own_messages.select { count.function.* }, :message_count, ROM::Types::Integer),
        )
      end

      private

      def all_folder = filed

      def column(query, name, type = ROM::Types::String) = ROM::SQL::Attribute[type].meta(sql_expr: query).as(name)

      def drafts_folder = where(draft: true)

      def filed = kept.where(draft: false)

      def first_message = own_messages.order(:received_at, :id).limit(1)

      def inbox_folder = inboxed.where(PRIMARY)

      def inboxed = filed.where(archived: false).awake

      def kept = exclude(status: SPAM).where(trashed: false)

      def last_message = own_messages.reverse(:received_at, :id).limit(1)

      def letters
        joined = own_messages.select(Sequel.function(:string_agg, Sequel.join(SEARCHED, " "), " "))

        Sequel.function(:coalesce, joined, "")
      end

      def own_messages = mail_messages.dataset.unordered.where(mail_thread_id: self[:id].qualified)

      def sent_folder = filed.where(sent: true)

      def snoozed_folder = asleep

      def spam_folder = with_status(SPAM)

      def starred_folder = where(starred: true, trashed: false)

      def tag_names
        names = mail_thread_tags.join(:tag).where(mail_thread_id: self[:id].qualified).dataset.unordered
        joined = names.select(Sequel.function(:string_agg, Blog::DB::Plugins::Taggings::NAME, " "))

        Sequel.function(:coalesce, joined, "")
      end

      def trash_folder = where(trashed: true)

      def updates_folder = inboxed.exclude(PRIMARY)
    end
  end
end
