# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Show < View
          include Components::Projects

          CLOSED = Blog::Types::ClosedTaskStatus.values
          COLUMNS = Blog::Types::TaskColumn.values
          LIVE_TABLES = %w[
            project_tags projects sprints tags task_comments task_contributors task_links task_series task_tags
            work_sessions
          ].freeze
          PUBLIC = Blog::Types::ProjectVisibility["public"]
          VIEWS = { "board" => ["fa-table-columns", ".views.board"], "list" => ["fa-list", ".views.list"] }.freeze

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :board, Blog::Types::Instance(Blog::BoardSizes)
          prop :view, Blog::Types::String.enum(*VIEWS.keys).optional, default: nil
          prop :tagging, Blog::Types::Hash
          prop :filter, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            BackLink(href: path(:admin_projects), variant: :gh, small: true, class: "editor-back") do
              t(".all_projects")
            end
            head
            facts
            FilterBar(project: @project, filter: @filter, shown: @counts.values.sum, tagging: @tagging)
            views
          end

          private

          def board(columns)
            div(class: "kb-bulk", data: { board_shows: "board" }) do
              Bulk(project_id: @project.id)
              div(class: "kb", role: "region", tabindex: 0, aria: { label: t(".board", name: @project.name) }) do
                input(type: "hidden", name: "return_to", value: here, form: Bulk::ID)
                COLUMNS.each do |name|
                  BoardColumn(
                    project_id: @project.id, name:, tasks: tasks_in(columns, name), count: @counts.fetch(name),
                    board: @board, return_to: here, query: filtered,
                  )
                end
              end
              Hint { t(".hint") }
            end
          end

          def counts
            open = @counts.values_at(*COLUMNS - CLOSED).sum

            span { t(".counts", open:, total: @counts.values.sum) }
          end

          def create_task
            Button(href: path(:admin_new_task, project: @project.key), icon: :add) { t(".create_task") }
          end

          def facts
            div(class: "kb-meta") do
              link(@project.repo_url, @project.repo, Blog::Constants::GITHUB_ICON) if @project.repo_url
              link(@project.url, bare_url(@project.url), :outbound) if site?
              counts
              published
              toggle
            end
          end

          def filtered = { q: @filter[:text] }.reject { |_, text| text.empty? }

          def head
            PageHead(title: @project.name, sub: tagline) do
              BulkToggle(form: Bulk::ID)
              create_task unless @project.archived_on
              Button(href: path(:admin_edit_project, id: @project.id), icon: :edit) { t(".edit") }
            end
          end

          def here = path(:admin_project, id: @project.id, **@board.grown, **filtered)

          def link(href, text, icon)
            a(href:, target: "_blank", rel: "noopener") { IconLabel(icon:) { text } }
          end

          def published
            return span { IconLabel(icon: "fa-solid fa-lock") { t(".private") } } unless published?

            span(class: "kb-published") { IconLabel(icon: "fa-solid fa-globe") { t(".published") } }
          end

          def published? = @project.board_published && @project.visibility == PUBLIC

          def site? = written?(@project.url) && @project.url != @project.repo_url

          def tagline = written?(@project.tagline) ? @project.tagline : t(".no_tagline")

          def tasks_in(columns, name) = columns.fetch(name, Blog::Constants::EMPTY_ARRAY)

          def toggle
            items = VIEWS.map do |view, (icon, text)|
              { text: t(text), href: path(:admin_project, id: @project.id, **@board.grown, **filtered, view:), icon:,
                current: view == @view, data: { board_pick: view } }
            end

            span(class: "kb-view") { SegmentedLinks(label: t(".view"), items:, labelled: true) }
          end

          def views
            columns = @tasks.group_by(&:board_column)

            div(class: "kb-views", data: { board_views: true, board_view: @view }) do
              board(columns)
              BoardList(project: @project, columns:, counts: @counts, board: @board, return_to: here, query: filtered)
            end
          end
        end
      end
    end
  end
end
