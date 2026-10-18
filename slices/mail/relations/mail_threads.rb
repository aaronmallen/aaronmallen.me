# frozen_string_literal: true

module Mail
  module Relations
    class MailThreads < Blog::DB::Relation
      FOLDERS = Blog::Types::MailFolder.values.to_h { [it, :"#{it}_folder"] }.freeze
      NEEDS_REPLY = "needs-reply"
      NOTIFICATION = /(@(github\.com|linear\.app|docs\.google\.com)|^drive-shares-(dm-)?noreply@google\.com)$/i
      PREVIEW = 500
      PRIMARY = Sequel.|({ category: nil }, { category: Blog::Types::MailCategory["personal"] })
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

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

        kept.where(holding(name))
      end

      def linkable = linkables(title: :subject, day: self.class.site_day(:received_at))

      def marked_spam_before(time) = where { marked_spam_at < time }

      def matching(text)
        return none if unmatchable?(text)

        pattern = like_pattern(text)
        written = mail_messages.matching(text).dataset.unordered.select(:mail_thread_id)

        where(Sequel.|(Sequel.ilike(:subject, pattern), Sequel.ilike(tag_names, pattern), { id: written }))
      end

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def shown = where(mail_account_id: mail_accounts.where(shown: true).dataset.unordered.select(:id))

      def waiting(rules)
        reasons = reasons(rules)
        return none if reasons.empty?

        found = filed.shown.where(archived: false).where(Sequel.|(*reasons.map(&:first)))
        found = found.exclude(notification) if rules.fetch(:skip_notifications)
        found.with_reason(rules)
      end

      def with_account
        named = mail_accounts.dataset.unordered.where(id: self[:mail_account_id].qualified).select(:name)

        select_append(column(named, :account))
      end

      def with_letter = with_preview.select_append(column(first_message.select(:body), :body))

      def with_preview = select_append(column(first_message.select(:reply_to), :reply_to), preview(first_message))

      def with_reason(rules)
        reasons = reasons(rules)

        select_append(column(reasons.empty? ? Sequel.cast(nil, String) : Sequel.case(reasons, nil), :reason))
      end

      def with_status(status) = where(status:)

      def with_summary
        select_append(
          column(first_message.select(Sequel.function(:coalesce, :from_name, :reply_to)), :sender),
          column(first_message.select(:reply_to), :reply_to),
          preview(last_message),
          column(own_messages.select { count.function.* }, :message_count, ROM::Types::Integer),
        )
      end

      private

      def all_folder = filed

      def column(query, name, type = ROM::Types::String) = ROM::SQL::Attribute[type].meta(sql_expr: query).as(name)

      def drafts_folder = where(draft: true)

      def filed = kept.where(draft: false)

      def first_message = own_messages.order(:received_at, :id).limit(1)

      def from_people
        sender = first_message.select(Sequel.function(:lower, Sequel.function(:coalesce, :from_name, :reply_to)))

        { sender => people.dataset.unordered.select(Sequel.function(:lower, :name)) }
      end

      def holding(name)
        held = mail_thread_labels.join(:mail_label).where(Sequel[:mail_labels][:name] => name).dataset.unordered

        Sequel.|({ id: held.select(:mail_thread_id) }, { id: mail_thread_tags.holding_every([name]) })
      end

      def inbox_folder = inboxed.where(PRIMARY)

      def inboxed = filed.where(archived: false).awake

      def kept = exclude(status: SPAM).where(trashed: false)

      def last_message = own_messages.order(:draft, Sequel.desc(:received_at), Sequel.desc(:id)).limit(1)

      def notification
        Sequel.like(Sequel.function(:coalesce, first_message.select(:reply_to), ""), NOTIFICATION)
      end

      def own_messages = mail_messages.dataset.unordered.where(mail_thread_id: self[:id].qualified)

      def preview(message) = column(message.select(Sequel.function(:left, :body, PREVIEW)), :preview)

      def reasons(rules) = Blog::Types::MailWaitReason.values.select { rules.fetch(it.to_sym) }.map { [wait(it), it] }

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

      def unread(condition) = Sequel.&({ status: UNREAD }, condition)

      def updates_folder = inboxed.exclude(PRIMARY)

      def wait(reason)
        case reason
          when "starred" then { starred: true }
          when "contact_form" then unread(mail_account_id: mail_accounts.contact_form.dataset.unordered.select(:id))
          when "people" then unread(from_people)
          when "needs_reply" then unread(holding(NEEDS_REPLY))
          else unread(important: true)
        end
      end
    end
  end
end
