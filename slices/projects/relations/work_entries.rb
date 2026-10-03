# frozen_string_literal: true

module Projects
  module Relations
    class WorkEntries < Blog::DB::Relation
      schema :work_entries, infer: true

      def in_order = order(self[:position].asc, self[:id].asc)

      def last_position = unordered.max(:position).to_i

      def linkable = linkables(title: Sequel.join([:role, ", ", :org]), day: self.class.site_day(:created_at))

      def matching(text) = containing(text, :org, :role, :blurb)

      def overlapping(first, last)
        where(Sequel[:from_year] <= last).where(Sequel.|({ to_year: nil }, Sequel[:to_year] >= first))
      end
    end
  end
end
