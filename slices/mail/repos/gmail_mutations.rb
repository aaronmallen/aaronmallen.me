# frozen_string_literal: true

module Mail
  module Repos
    class GmailMutations < Blog::DB::Repo
      GMAIL = Blog::Types::MailProvider["gmail"]

      def account(address)
        mail_accounts.add(address, provider: GMAIL)
        mail_accounts.where(address:).one
      end

      def add_label(thread_id, label_id)
        mail_thread_labels.add([{ mail_thread_id: thread_id, mail_label_id: label_id }])
      end

      def delete_thread(account_id, gmail_id) = mail_threads.where(mail_account_id: account_id, gmail_id:).delete

      def follow(account_id, history_id)
        mail_accounts.where(id: account_id).update(history_id:, updated_at: Time.now)
      end

      def relabel(account_id, thread, now: Time.now)
        id = thread_id(account_id, thread.gmail_id)
        return unless id && same_messages?(id, thread.messages)

        transaction do
          gmail_threads.where(id:).relabel(thread.row, now)
          label(id, account_id, thread.label_ids)
          id
        end
      end

      def sign(account_id, signature, now: Time.now)
        signature = nil if signature.empty?
        mail_accounts.where(id: account_id).update(signature:, settings_synced_at: now)
      end

      def store_draft(thread_id, draft, kept, now: Time.now)
        message = draft.messages.first

        transaction do
          mail_messages.where(mail_thread_id: thread_id).exclude(gmail_id: kept).delete
          upsert_messages(thread_id, [message], now)
          store_attachments(thread_id, draft.attachments)
          gmail_threads.where(id: thread_id).restate(message, now)
        end
      end

      def store_labels(account_id, labels, now: Time.now)
        rows = labels.map { { **it, mail_account_id: account_id, created_at: now, updated_at: now } }

        transaction do
          mail_labels.where(mail_account_id: account_id).exclude(gmail_id: rows.map { it[:gmail_id] }).delete
          mail_labels.store(rows)
        end
      end

      def store_thread(account_id, thread, now: Time.now)
        transaction do
          id = upsert_thread(account_id, thread.thread(now:), now)
          store_messages(id, thread.messages, now)
          store_attachments(id, thread.attachments)
          label(id, account_id, thread.label_ids)
        end
      end

      def thread_id(account_id, gmail_id) = mail_threads.where(mail_account_id: account_id, gmail_id:).pluck(:id).first

      private

      def attachment_rows(thread_id, attachments)
        ids = mail_messages.where(mail_thread_id: thread_id).dataset.select_map(%i[gmail_id id]).to_h

        attachments.to_h do |gmail_id, files|
          id = ids.fetch(gmail_id)
          [id, files.map { { **it, mail_message_id: id } }]
        end
      end

      def label(id, account_id, gmail_ids)
        label_ids = mail_labels.where(mail_account_id: account_id, gmail_id: gmail_ids).pluck(:id)

        mail_thread_labels.where(mail_thread_id: id).exclude(mail_label_id: label_ids).delete
        rows = label_ids.map { |label_id| { mail_thread_id: id, mail_label_id: label_id } }
        mail_thread_labels.add(rows)
      end

      def same_messages?(id, messages)
        mail_messages.where(mail_thread_id: id).pluck(:gmail_id).sort == messages.map { it[:gmail_id] }.sort
      end

      def store_attachments(thread_id, attachments)
        rows = attachment_rows(thread_id, attachments)
        stored = stored_attachments(rows.keys)
        rows.reject! { |id, files| files.to_set == stored.fetch(id, []).to_set }

        mail_attachments.where(mail_message_id: rows.keys).delete
        mail_attachments.multi_insert(rows.values.flatten)
      end

      def store_messages(id, messages, now)
        mail_messages.where(mail_thread_id: id).exclude(gmail_id: messages.map { it[:gmail_id] }).delete
        upsert_messages(id, messages, now)
      end

      def stored_attachments(ids)
        mail_attachments.where(mail_message_id: ids).dataset.to_a.group_by { it[:mail_message_id] }
      end

      def upsert_messages(id, messages, now)
        mail_messages.store(messages.map { { **it, mail_thread_id: id, created_at: now, updated_at: now } })
      end

      def upsert_thread(account_id, row, now)
        stored = gmail_threads.store({ **row, mail_account_id: account_id, created_at: now, updated_at: now })

        stored.first&.fetch(:id) || thread_id(account_id, row.fetch(:gmail_id))
      end
    end
  end
end
