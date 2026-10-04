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

      def days = unordered.distinct.select(:entry_date)

      def days_written = unordered.distinct.select(:entry_date).count

      def later_than(day) = where { entry_date > day }

      def linkable = linkables(title: Sequel.function(:split_part, :body, "\n", 1), day: :entry_date)

      def matching(text) = containing(text, :body)

      def newest_first = order(self[:entry_date].desc, self[:entry_time].desc, self[:id].desc)

      def oldest_first = order(self[:entry_date].asc, self[:entry_time].asc, self[:id].asc)

      def on(date) = where(entry_date: date)

      def tagged(names)
        return none if unmatchable?(names)

        where(id: holding_every(names.map { it.to_s.downcase }.uniq).dataset)
      end

      def word_total = unordered.sum(WORDS).to_i

      private

      def holding_every(names)
        owner = journal_entry_tags[:journal_entry_id].qualified
        name = tags[:name].qualified
        matched = journal_entry_tags.unordered.join(:tag).where(name => names)

        matched.group(owner).having(Sequel.function(:count, name).distinct => names.length).select(owner)
      end
    end
  end
end
