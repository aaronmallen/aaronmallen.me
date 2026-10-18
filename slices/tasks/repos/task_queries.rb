# frozen_string_literal: true

module Tasks
  module Repos
    class TaskQueries < Blog::DB::Repo
      BOARD_ORDER = [Sequel.desc(Sequel[:tasks][:completed_at]), Sequel[:tasks][:position], Sequel[:tasks][:id]].freeze
      COLUMNS = Blog::Types::TaskColumn.values.freeze
      OPEN = Blog::Types::TaskStatus["open"]
      COLUMN = Sequel.case({ { status: OPEN } => Sequel.cast(:stage, String) }, Sequel.cast(:status, String))
      LINK_LIMIT = 6
      TAG_ROW = %i[id title status completed_at].freeze
      TODAY = Blog::Types::TaskFilter["today"]

      DAY = 86_400

      include Deps[
        "settings",
        project_queries: "projects.repos.project_queries",
        task_label_queries: "repos.task_label_queries",
      ]

      def board_counts(project_id)
        counted = on_project(tasks, project_id).unordered
        counts = counted.select { COLUMNS.map { integer.count(id).filter(COLUMN => it).as(it.to_sym) } }.one

        counts.to_h.transform_keys(&:to_s)
      end

      def by_decision(decision_id) = tasks.where(id: record_links.sourced_task_ids(decision_id)).one

      def by_id(id) = with_details.by_pk(id).one

      def by_ids(ids) = tasks.where(id: ids).combine(:tags).to_a

      def by_tag(tag) = listed.combine(:sprint).tagged([tag]).open_first.to_a

      def detailed(id) = with_details.combine(:sprint).by_pk(id).one

      def detailed_in_order(ids)
        found = with_details.combine(:sprint).where(id: ids).to_a.to_h { [it.id, it] }

        found.values_at(*ids)
      end

      def exist?(id) = tasks.by_pk(id).exist?

      def filtered(page:, closed_in_window: false, **filters)
        search = by_project(**filters)
        from, to = filters.values_at(:from, :to)
        found = tasks.narrowed(**search)
        found = found.closed(from..to) if closed_in_window && (from || to)
        rows = listed(found).combine(:sprint).newest_first.ids_first(search[:label_ids]).paged(page).to_a

        Structs::FoundTasks.new(paged: page.fill(rows), total: found.count)
      end

      def finished(page:, from: nil, to: nil, **search)
        days = (from..to if from && to)

        search = by_project(**search)
        found = listed.combine(:sprint).closed(days).searched(**search)

        page.fill(found.newest_first.ids_first(search[:label_ids]).paged(page).to_a)
      end

      def finished_counts(day) = tasks.finished_counts(day).one.to_h

      def id_at(filter, sprint:, offset:) = pool(tasks, filter, sprint).in_order.limit(1, offset).pluck(:id).first

      def id_by_label(label)
        found = label.include?("-") ? tasks : tasks.where(project_id: nil)

        task_label_queries.labelled_as(found, label).pluck(:id).first
      end

      def ids_of(ids) = tasks.where(id: ids).select(:id).to_a

      def in_progress = tasks.in_progress.in_order.to_a

      def in_sprint(sprint_id) = listed.for_sprint(sprint_id).in_order.to_a

      def link_targets(id, text)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_ARRAY if query.empty?

        found = tasks.labelled.linkable_from(id).open_first.limit(LINK_LIMIT)

        (task_label_queries.labelled_as(found, query).to_a + found.titled(query).to_a).uniq(&:id).first(LINK_LIMIT)
      end

      def list(filter, sprint:, page:, **search)
        search = by_project(**search)
        found = pool(listed, filter, sprint).searched(**search)

        page.fill(found.in_order.ids_first(search[:label_ids]).paged(page).to_a)
      end

      def on_board(project_id, sizes)
        on_project(listed, project_id).where(id: shown(project_id, sizes)).order(*BOARD_ORDER).to_a
      end

      def on_public_board(project_id, sizes)
        on_project(tasks.labelled, project_id).where(id: shown(project_id, sizes)).order(*BOARD_ORDER).to_a
      end

      def on_public_board_by_number(project_id, number)
        tasks.labelled.where(project_id:, number:).combine(:source, :incoming_links, :outgoing_links).one
      end

      def open_after(task) = tasks.beside(task).following(task).limit(1).one

      def open_before(task) = tasks.beside(task).preceding(task).limit(1).one

      def open_choices = tasks.open.in_order.select(:id, :title).to_a

      def open_counts(sprint:, planned:)
        tasks.open_counts(sprint.id, planned.map(&:id)).one.to_h.transform_keys(&:to_s)
      end

      def page_by_tag(tag, page) = page.fill(tasks.tagged([tag]).open_first.select(*TAG_ROW).paged(page).to_a)

      def planned(sprints, **search)
        search = by_project(**search)

        listed.for_sprint(sprints.map(&:id)).open.searched(**search).in_order.ids_first(search[:label_ids]).to_a
      end

      def public_board_slugs(task_ids)
        by_task = tasks.where(id: task_ids).exclude(project_id: nil).pluck(:id, :project_id).to_h
        slugs = project_queries.public_boards(by_task.values).to_h { [it.id, it.slug] }

        by_task.filter_map { |id, project_id| [id, [slugs[project_id]]] if slugs.key?(project_id) }.to_h
      end

      def recurring = listed.combine(:sprint).where(id: task_series.pluck(:task_id)).in_order.to_a

      private

      def by_project(**) = task_label_queries.terms(**)

      def listed(found = tasks) = found.select(*found.schema.qualified.reject { it.name == :note }).detailed

      def on_project(found, project_id) = recent(found.searched(project_ids: [project_id]))

      def pool(found, filter, sprint) = (filter == TODAY ? found.for_sprint(sprint.id) : found.in_list(filter)).open

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
