# frozen_string_literal: true

module Tasks
  module Repos
    class TaskQueries < Blog::DB::Repo
      BOARD_ORDER = [Sequel.desc(Sequel[:tasks][:completed_at]), Sequel[:tasks][:position], Sequel[:tasks][:id]].freeze
      COLUMNS = Blog::Types::TaskColumn.values.freeze
      OPEN = Blog::Types::TaskStatus["open"]
      COLUMN = Sequel.case({ { status: OPEN } => Sequel.cast(:stage, String) }, Sequel.cast(:status, String))
      KEY = /\A#?(\d{1,9})\z/
      LINK_LIMIT = 6
      TODAY = Blog::Types::TaskFilter["today"]

      DAY = 86_400

      include Deps["settings", project_queries: "projects.repos.project_queries"]

      def all_open = tasks.open.in_order.to_a

      def board_counts(project_id)
        counted = on_project(tasks, project_id).unordered
        counts = counted.select { COLUMNS.map { integer.count(id).filter(COLUMN => it).as(it.to_sym) } }.one

        counts.to_h.transform_keys(&:to_s)
      end

      def by_decision(decision_id) = tasks.where(id: record_links.sourced_task_ids(decision_id)).one

      def by_id(id) = with_details.by_pk(id).one

      def by_ids(ids) = tasks.where(id: ids).combine(:tags).to_a

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

      def on_board(project_id, sizes)
        on_project(with_details, project_id).where(id: shown(project_id, sizes)).order(*BOARD_ORDER).to_a
      end

      def on_public_board(project_id, sizes)
        on_project(tasks, project_id).where(id: shown(project_id, sizes)).order(*BOARD_ORDER).to_a
      end

      def on_public_board_by_id(project_id, id)
        links = { incoming_links: :from_task, outgoing_links: :to_task }

        tasks.searched(project_ids: project_id).combine(:source, **links).by_pk(id).one
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

      def public_board_slugs(task_ids)
        by_task = tasks.where(id: task_ids).exclude(project_id: nil).pluck(:id, :project_id).to_h
        slugs = project_queries.public_boards(by_task.values).to_h { [it.id, it.slug] }

        by_task.filter_map { |id, project_id| [id, [slugs[project_id]]] if slugs.key?(project_id) }.to_h
      end

      def recurring = with_details.combine(:sprint).where(id: task_series.pluck(:task_id)).in_order.to_a

      def timeline(task_id) = task_timeline.for_task(task_id).oldest_first.to_a

      private

      def by_project(projects: [], **search)
        projects.empty? ? search : { **search, project_ids: project_queries.ids_by_slug(projects) }
      end

      def on_project(found, project_id) = recent(found.searched(project_ids: [project_id]))

      def recent(found)
        since = Time.now - (settings.board[:closed_days] * DAY)
        found.where(Sequel.|({ completed_at: nil }, Sequel[:completed_at] > since))
      end

      def shown(project_id, sizes)
        rank = Sequel.function(:row_number).over(partition: COLUMN, order: BOARD_ORDER)
        ranked = on_project(tasks, project_id).dataset.unordered.select(:id, COLUMN.as(:column), rank.as(:rank))

        ranked.from_self.where(Sequel.|(*sizes.map { |column, size| { column:, rank: ..size } })).select(:id)
      end

      def with_details = tasks.detailed
    end
  end
end
