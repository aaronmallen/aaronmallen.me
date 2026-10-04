# frozen_string_literal: true

module Record
  module Repos
    class ReviewNoteRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def entry(period, starts_on)
        ids = review_notes.of(period, starts_on).select(:journal_entry_id)

        journal_entries.combine(:tags).where(id: ids.dataset).one
      end
    end
  end
end
