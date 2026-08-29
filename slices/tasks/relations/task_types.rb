# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTypes < Blog::DB::Relation
      schema :task_types, infer: true

      def counts_by_color = unordered.select(:color) { integer.count(id).as(:count) }.group(:color)

      def ids = unordered.dataset.select(:id)

      def in_order = order(self[:position].asc, self[:id].asc)

      def last_position = unordered.max(:position).to_i

      def named(name) = where(Sequel.function(:lower, Sequel[:task_types][:name]) => name)

      def next_color = least_used(color_counts)

      private

      def color_counts
        Blog::Types::TagColor.values.to_h { [it, 0] }.merge(counts_by_color.to_a.to_h { [it[:color], it[:count]] })
      end

      def least_used(counts)
        fewest = counts.values.min

        counts.select { |_, count| count == fewest }.keys.sample
      end
    end
  end
end
