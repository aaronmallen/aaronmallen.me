# frozen_string_literal: true

module Tasks
  module Repos
    class TaskQueries < Blog::DB::Repo
      KEY = /\A#?(\d{1,9})\z/
      LINK_LIMIT = 6
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[project_queries: "projects.repos.project_queries"]

      def all_open = tasks.open.in_order.to_a

      def by_id(id) = with_details.by_pk(id).one

      def by_tag(tag) = with_details.combine(:sprint).tagged([tag]).open_first.to_a

      def detailed(id) = with_details.combine(:sprint).by_pk(id).one

      def exist?(id) = tasks.by_pk(id).exist?

      def filtered(page:, **filters)
        found = tasks.narrowed(**by_project(**filters))
        rows = found.detailed.combine(:sprint).newest_first.paged(page).to_a

        Structs::FoundTasks.new(paged: page.fill(rows), total: found.count)
      end

      def finished(page:, from: nil, to: nil, **search)
        days = (from..to if from && to)

        found = with_details.combine(:sprint).closed(days).searched(**by_project(**search))

        page.fill(found.newest_first.paged(page).to_a)
      end

      def finished_counts(day) = tasks.finished_counts(day).one.to_h

      def in_progress = all_open.select(&:in_progress?)

      def in_sprint(sprint_id) = with_details.for_sprint(sprint_id).in_order.to_a

      def link_targets(id, text)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_ARRAY if query.empty?

        found = tasks.linkable_from(id)
        key = query[KEY, 1]
        found = key ? found.where(id: key.to_i) : found.titled(query)

        found.open_first.limit(LINK_LIMIT).to_a
      end

      def list(filter, sprint:, page:, **search)
        found = filter == TODAY ? with_details.for_sprint(sprint.id) : with_details.in_list(filter)

        page.fill(found.open.searched(**by_project(**search)).in_order.paged(page).to_a)
      end

      def open_after(task) = tasks.beside(task).following(task).limit(1).one

      def open_before(task) = tasks.beside(task).preceding(task).limit(1).one

      def open_counts(sprint:, planned:)
        tasks.open_counts(sprint.id, planned.map(&:id)).one.to_h.transform_keys(&:to_s)
      end

      def open_in_list(list) = with_details.in_list(list).open.in_order.to_a

      def planned(sprints, **search)
        with_details.for_sprint(sprints.map(&:id)).open.searched(**by_project(**search)).in_order.to_a
      end

      def timeline(task_id) = task_timeline.for_task(task_id).oldest_first.to_a

      private

      def by_project(projects: [], **search)
        projects.empty? ? search : { **search, project_ids: project_queries.ids_by_slug(projects) }
      end

      def with_details = tasks.detailed
    end
  end
end
