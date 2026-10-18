# frozen_string_literal: true

module Mail
  module Structs
    GmailHistory = Data.define(:records)

    class GmailHistory
      LABEL_CHANGES = %w[labelsAdded labelsRemoved].freeze
      LABELS_ADDED = %w[messagesAdded labelsAdded].freeze
      MESSAGE_CHANGES = %w[messagesAdded messagesDeleted].freeze
      USER_LABEL_PREFIX = "Label_"

      def added_user_labels
        added = records.flat_map { |record| LABELS_ADDED.flat_map { record.fetch(it, []) } }
        ids = added.flat_map { [*it["labelIds"], *it.dig("message", "labelIds")] }
        ids.select { it.start_with?(USER_LABEL_PREFIX) }
      end

      def label_only_thread_ids
        labeled, changed = records.partition { changes?(it, LABEL_CHANGES) && !changes?(it, MESSAGE_CHANGES) }

        thread_ids(labeled) - thread_ids(changed)
      end

      def thread_ids(of = records) = of.flat_map { it.fetch("messages", []) }.map { it.fetch("threadId") }.uniq

      private

      def changes?(record, types) = types.any? { record.fetch(it, nil) }
    end
  end
end
