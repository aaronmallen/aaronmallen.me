# frozen_string_literal: true

module Tasks
  module Repos
    class SprintQueries < DB::Repo
      def after(date) = sprints.dated_after(date).in_date_order.to_a

      def between(from:, to:, page:) = page.fill(sprints.dated_between(from, to).in_date_order.paged(page).to_a)

      def by_id(id) = sprints.by_pk(id).one

      def counted_between(from:, to:) = sprints.dated_between(from, to).with_task_counts.in_date_order.to_a

      def on(date) = sprints.on(date).one
    end
  end
end
