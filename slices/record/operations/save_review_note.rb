# frozen_string_literal: true

module Record
  module Operations
    class SaveReviewNote < Blog::Operation
      TAG = "review"
      TAG_SEPARATOR = ", "

      include Deps[
        journal_entry_repo: "repos.journal_entry_repo",
        save_journal_entry: "operations.save_journal_entry",
        update_journal_entry: "operations.update_journal_entry",
      ]

      def call(body, on:, now: Time.now)
        step write(journal_entry_repo.tagged_on(TAG, on), body, on, now)
      end

      private

      def tags(entry) = (entry.tags.map(&:name) | [TAG]).join(TAG_SEPARATOR)

      def write(entry, body, on, now)
        return save_journal_entry.call({ body:, entry_date: on.iso8601, tags: TAG }, now:, latest: on) unless entry

        update_journal_entry.call(entry.id, { body:, tags: tags(entry) })
      end
    end
  end
end
