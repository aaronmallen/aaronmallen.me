# frozen_string_literal: true

module Tasks
  module Relations
    class Sprints < Blog::DB::Relation
      schema :sprints, infer: true

      def before_sprint(id) = dated_before(by_pk(id).dates)

      def count_arrivals(id, arrived)
        by_pk(id).stamped(:update).call(carried_in: Sequel[:carried_in] + arrived)
      end

      def dated_after(date) = where { sprint_date > date }

      def dated_before(date) = where { sprint_date < date }

      def dated_between(first, last) = where(sprint_date: Range.new(first, last))

      def dates = unordered.dataset.select(:sprint_date)

      def ids = unordered.dataset.select(:id)

      def in_date_order = order(self[:sprint_date].asc)

      def insert_missing(date)
        now = Time.now

        upsert({ sprint_date: date, created_at: now, updated_at: now }, target: :sprint_date)
      end

      def on(date) = where(sprint_date: date)

      def with_task_counts
        task_id = tasks[:id].qualified

        counted = left_join(:tasks, sprint_id: :id).group(self[:id].qualified)

        counted.select_append { integer.count(task_id).as(:task_count) }
      end
    end
  end
end
