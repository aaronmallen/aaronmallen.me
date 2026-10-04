# frozen_string_literal: true

module Record
  module Operations
    class SaveReviewNote < Blog::Operation
      TAG = "review"
      TAG_SEPARATOR = ", "

      include Deps[
        review_note_repo: "repos.review_note_repo",
        save_journal_entry: "operations.save_journal_entry",
        update_journal_entry: "operations.update_journal_entry",
      ]

      def call(body, period:, on:, now: Time.now)
        range = Blog::ReviewRange.call(period, on)

        transaction { step write(review_note_repo.entry(period, range.first), body, period, range, now) }
      end

      private

      def create(body, period, range, now)
        from, to = range
        entry = step save_journal_entry.call({ body:, entry_date: to.iso8601, tags: TAG }, now:, latest: to)
        review_note_repo.create(period:, starts_on: from, journal_entry_id: entry.id)

        Success(entry)
      end

      def tags(entry) = (entry.tags.map(&:name) | [TAG]).join(TAG_SEPARATOR)

      def write(entry, body, period, range, now)
        return create(body, period, range, now) unless entry

        update_journal_entry.call(entry.id, { body:, tags: tags(entry) })
      end
    end
  end
end
