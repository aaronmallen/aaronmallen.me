# frozen_string_literal: true

module Tasks
  module Repos
    class SprintRepo < Blog::DB::Repo
      commands delete: :by_pk

      def after(date) = sprints.dated_after(date).in_date_order.to_a

      def between(first, last, page) = page.fill(sprints.dated_between(first, last).in_date_order.paged(page).to_a)

      def by_id(id) = sprints.by_pk(id).one

      def claim(date) = on(date) || start(date)

      def count_arrivals(id, arrived) = sprints.count_arrivals(id, arrived)

      def counted_between(first, last) = sprints.dated_between(first, last).with_task_counts.in_date_order.to_a

      def lock_roll_over = sprints.lock_roll_over_until_commit

      def on(date) = sprints.on(date).one

      private

      def start(date)
        sprints.insert_missing(date)
        on(date)
      end
    end
  end
end
