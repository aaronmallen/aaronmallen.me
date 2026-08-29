# frozen_string_literal: true

module Record
  module Relations
    class JournalEntries < Blog::DB::Relation
      WORDS = Sequel.function(:regexp_count, :body, "\\S+")

      schema :journal_entries, infer: true do
        associations do
          has_many :journal_entry_tags
          has_many :tags, through: :journal_entry_tags, view: :in_name_order
        end
      end

      def between(from, to) = where(entry_date: from..to)

      def days_written = unordered.distinct.select(:entry_date).count

      def matching(text) = where(Sequel.ilike(:body, "%#{dataset.escape_like(text)}%"))

      def newest_first = order(self[:entry_date].desc, self[:entry_time].desc, self[:id].desc)

      def on(date) = where(entry_date: date)

      def word_total = unordered.sum(WORDS).to_i
    end
  end
end
