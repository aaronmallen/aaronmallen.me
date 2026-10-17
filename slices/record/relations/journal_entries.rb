# frozen_string_literal: true

module Record
  module Relations
    class JournalEntries < Blog::DB::Relation
      OPENING = 160
      OPENING_BLANKS = " \t\r\n"
      COUNT = Sequel.function(:count).*.as(:entries)
      WORDS = Sequel.function(:coalesce, Sequel.function(:sum, :word_count), 0).as(:words)

      schema :journal_entries, infer: true do
        associations do
          has_many :journal_entry_tags
          has_many :tags, through: :journal_entry_tags, view: :in_name_order
        end
      end

      def between(from, to) = where(entry_date: from..to)

      def days = unordered.distinct.select(:entry_date)

      def later_than(day) = where { entry_date > day }

      def linkable = linkables(title: Sequel.function(:split_part, :body, "\n", 1), day: :entry_date)

      def matching(text) = containing(text, :body)

      def newest_first = order(self[:entry_date].desc, self[:entry_time].desc, self[:id].desc)

      def oldest_first = order(self[:entry_date].asc, self[:entry_time].asc, self[:id].asc)

      def on(date) = where(entry_date: date)

      def opening
        select(:id, :entry_date).select_append { string.left(string.ltrim(body, OPENING_BLANKS), OPENING).as(:body) }
      end

      def tagged(names)
        return none if unmatchable?(names)

        where(id: journal_entry_tags.holding_every(names).dataset)
      end

      def totals(from, to)
        written = Sequel.function(:count, :entry_date).distinct.filter(entry_date: from..to).as(:written)

        unordered.dataset.select(COUNT, WORDS, written).first
      end
    end
  end
end
