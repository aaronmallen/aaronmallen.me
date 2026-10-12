# frozen_string_literal: true

module Mail
  module Repos
    class ThreadQueries < Blog::DB::Repo
      FOLDER = Blog::Types::MailFolder
      THREAD = Sequel[:mail_threads]
      UNREAD = Blog::Types::MessageStatus["unread"]
      COUNTED = {
        FOLDER["inbox"] => true, FOLDER["updates"] => true,
        FOLDER["snoozed"] => false, FOLDER["drafts"] => false, FOLDER["spam"] => false,
      }.freeze
      FRESH = { THREAD[:status] => UNREAD, THREAD[:trashed] => false }.freeze

      def accounts = mail_accounts.where(shown: true).form_last.to_a

      def attachment(message_id, part_id)
        mail_attachments.where(mail_message_id: message_id, part_id:).combine(mail_message: :mail_thread).one
      end

      def by_id(id)
        mail_threads.with_summary.combine(:mail_labels, :tags, mail_messages: :mail_attachments).by_pk(id).one
      end

      def every_account = mail_accounts.form_last.to_a

      def folder_counts(account: nil)
        COUNTED.to_h do |folder, unread|
          found = held(mail_threads.in_folder(folder), account)
          [folder, (unread ? found.with_status(UNREAD) : found).count]
        end
      end

      def labels
        counts = unread_labels

        shown = accounts.map(&:id)

        label_names.select { shown.include?(it.first) }.group_by(&:first).transform_values do |pairs|
          pairs.map { |account, name| [name, counts.fetch([account, name], 0)] }
        end
      end

      def page_listed(page, **)
        page.fill(listed(**).with_summary.combine(:mail_labels, :tags).newest_first.paged(page).to_a)
      end

      def unread_by_account
        mail_threads.shown.in_folder(FOLDER["inbox"]).with_status(UNREAD).dataset.unordered
                    .group_and_count(:mail_account_id).as_hash(:mail_account_id, :count)
      end

      private

      def held(found, account) = account ? found.shown.where(mail_account_id: account) : found.shown

      def label_names
        named = mail_labels.dataset.unordered.select_map(%i[mail_account_id name])
        (named + tagged.distinct.select_map([THREAD[:mail_account_id], Sequel[:tags][:name]])).uniq.sort
      end

      def label_threads
        threads = mail_labels.dataset.unordered.join(:mail_thread_labels, mail_label_id: :id)
        threads.join(:mail_threads, id: Sequel[:mail_thread_labels][:mail_thread_id])
      end

      def listed(folder:, account: nil, label: nil, unread: false, search: nil)
        found = held(label ? mail_threads.labeled(label) : mail_threads.in_folder(folder), account)
        found = found.with_status(UNREAD) if unread
        search ? found.matching(search) : found
      end

      def tagged
        tags = mail_thread_tags.dataset.unordered.join(:tags, id: :tag_id)
        tags.join(:mail_threads, id: Sequel[:mail_thread_tags][:mail_thread_id])
      end

      def unread(threads, name)
        threads.where(FRESH).group_and_count(THREAD[:mail_account_id].as(:account), name.as(:name)).to_a
      end

      def unread_labels
        rows = unread(label_threads, Sequel[:mail_labels][:name]) + unread(tagged, Sequel[:tags][:name])

        rows.to_h { [[it[:account], it[:name]], it[:count]] }
      end
    end
  end
end
