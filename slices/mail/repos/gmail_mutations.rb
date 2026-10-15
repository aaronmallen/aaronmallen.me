# frozen_string_literal: true

module Mail
  module Repos
    class GmailMutations < Blog::DB::Repo
      GMAIL = Blog::Types::MailProvider["gmail"]
      MESSAGE_COLUMNS = %i[subject reply_to from_name body html_body received_at updated_at].freeze
      SPAM = Blog::Types::MessageStatus["spam"]
      THREAD_COLUMNS = %i[
        subject status starred archived trashed sent draft important category received_at updated_at
      ].freeze

      def account(address)
        mail_accounts.dataset.insert_conflict(target: :address).insert(provider: GMAIL, name: address, address:)
        mail_accounts.where(address:).one
      end

      def add_label(thread_id, label_id)
        mail_thread_labels.dataset.insert_conflict.insert(mail_thread_id: thread_id, mail_label_id: label_id)
      end

      def address(account_id) = mail_accounts.where(id: account_id, provider: GMAIL).pluck(:address).first

      def delete_thread(account_id, gmail_id) = mail_threads.where(mail_account_id: account_id, gmail_id:).delete

      def follow(account_id, history_id)
        mail_accounts.where(id: account_id).dataset.update(history_id:, updated_at: Time.now)
      end

      def label_ids(account_id) = mail_labels.where(mail_account_id: account_id).pluck(:gmail_id)

      def label_named(account_id, name) = mail_labels.where(mail_account_id: account_id, name:).one

      def sign(account_id, signature, now: Time.now)
        signature = nil if signature.empty?
        mail_accounts.where(id: account_id).dataset.update(signature:, settings_synced_at: now)
      end

      def store_labels(account_id, labels, now: Time.now)
        rows = labels.map { { **it, mail_account_id: account_id, created_at: now, updated_at: now } }

        transaction do
          mail_labels.where(mail_account_id: account_id).exclude(gmail_id: rows.map { it[:gmail_id] }).delete
          mail_labels.dataset.insert_conflict(
            target: %i[mail_account_id gmail_id], update: mail_labels.excluded(%i[name updated_at]),
          ).multi_insert(rows)
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

      private

      def attachment_rows(thread_id, attachments)
        ids = mail_messages.where(mail_thread_id: thread_id).dataset.select_map(%i[gmail_id id]).to_h

        attachments.to_h do |gmail_id, files|
          id = ids.fetch(gmail_id)
          [id, files.map { { **it, mail_message_id: id } }]
        end
      end

      def changed(table, columns)
        Sequel.lit("? IS DISTINCT FROM ?", columns.map { Sequel[table][it] }, columns.map { Sequel[:excluded][it] })
      end

      def label(id, account_id, gmail_ids)
        label_ids = mail_labels.where(mail_account_id: account_id, gmail_id: gmail_ids).pluck(:id)

        mail_thread_labels.where(mail_thread_id: id).exclude(mail_label_id: label_ids).delete
        rows = label_ids.map { |label_id| { mail_thread_id: id, mail_label_id: label_id } }
        mail_thread_labels.dataset.insert_conflict.multi_insert(rows)
      end

      def marked_spam_at
        kept = Sequel.function(:coalesce, Sequel[:mail_threads][:marked_spam_at], Sequel[:excluded][:marked_spam_at])

        Sequel.case([[{ Sequel[:excluded][:status] => SPAM }, kept]], nil)
      end

      def store_attachments(thread_id, attachments)
        rows = attachment_rows(thread_id, attachments)
        stored = stored_attachments(rows.keys)
        rows.reject! { |id, files| files.to_set == stored.fetch(id, []).to_set }

        mail_attachments.where(mail_message_id: rows.keys).delete
        mail_attachments.dataset.multi_insert(rows.values.flatten)
      end

      def store_messages(id, messages, now)
        rows = messages.map { { **it, mail_thread_id: id, created_at: now, updated_at: now } }

        mail_messages.where(mail_thread_id: id).exclude(gmail_id: rows.map { it[:gmail_id] }).delete
        mail_messages.dataset.insert_conflict(
          target: %i[mail_thread_id gmail_id], update: mail_messages.excluded(MESSAGE_COLUMNS),
          update_where: changed(:mail_messages, MESSAGE_COLUMNS - %i[updated_at]),
        ).multi_insert(rows)
      end

      def stored_attachments(ids)
        mail_attachments.where(mail_message_id: ids).dataset.to_a.group_by { it[:mail_message_id] }
      end

      def thread_id(account_id, gmail_id) = mail_threads.where(mail_account_id: account_id, gmail_id:).pluck(:id).first

      def upsert_thread(account_id, row, now)
        update = { **mail_threads.excluded(THREAD_COLUMNS), marked_spam_at: }
        update_where = changed(:mail_threads, THREAD_COLUMNS - %i[updated_at])
        stored = mail_threads.dataset.returning(:id).insert_conflict(
          target: %i[mail_account_id gmail_id], update:, update_where:,
        ).insert(**row, mail_account_id: account_id, created_at: now, updated_at: now)

        stored.first&.fetch(:id) || thread_id(account_id, row.fetch(:gmail_id))
      end
    end
  end
end
