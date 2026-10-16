# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Show < View
          include Components::Projects

          CLOSED = Blog::Types::ClosedTaskStatus.values
          COLUMNS = Blog::Types::TaskColumn.values
          GITHUB = "https://github.com/%s"
          LIVE_TABLES = %w[
            project_tags projects sprints task_comments task_contributors task_links task_series task_tags work_sessions
          ].freeze
          NAMES = Components::Projects::BoardCard::NAMES
          PUBLIC = Blog::Types::ProjectVisibility["public"]
          SCHEME = %r{\Ahttps?://}

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :sizes, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :step, Blog::Types::Integer

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            BackLink(href: path(:admin_projects), variant: :gh, small: true, class: "editor-back") do
              t(".all_projects")
            end
            head
            facts
            board
            Hint { t(".hint") }
          end

          private

          def board
            columns = @tasks.group_by(&:board_column)

            div(class: "kb-bulk") do
              Bulk(project_id: @project.id)
              div(class: "kb", aria: { label: t(".board", name: @project.name) }) do
                input(type: "hidden", name: "return_to", value: here, form: Bulk::ID)
                COLUMNS.each { column(it, columns.fetch(it, Blog::Constants::EMPTY_ARRAY)) }
              end
            end
          end

          def column(name, tasks)
            label = t(NAMES.fetch(name))

            section(class: ["kcol", "k-#{name}"], aria: { label: }, data: { board_column: name }) do
              column_head(label, @counts.fetch(name))
              div(class: "kcol-list", data: { key_list: true }) do
                next p(class: "kcol-empty") { t(".empty") } if tasks.empty?

                tasks.each { BoardCard(task: it, project_id: @project.id, return_to: here) }
              end
              more(name, tasks.size)
            end
          end

          def column_head(label, count)
            div(class: "kcol-head") do
              span(class: "kcol-dot", aria: { hidden: true })
              h2 { label }
              span(class: "kcol-count") { count.to_s }
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
              link(repo_url, @project.repo, "fa-brands fa-github") if repo_url
              link(@project.url, @project.url.sub(SCHEME, ""), :outbound) if site?
              counts
              published
            end
          end

          def grown = @sizes.reject { |_, size| size == @step }

          def head
            PageHead(title: @project.name, sub: tagline) do
              BulkToggle(form: Bulk::ID)
              create_task unless @project.archived_on
              Button(href: path(:admin_edit_project, id: @project.id), icon: :edit) do
                t(".edit")
              end
            end
          end

          def here = path(:admin_project, id: @project.id, **grown.transform_keys(&:to_sym))

          def link(href, text, icon)
            a(href:, target: "_blank", rel: "noopener") { IconLabel(icon:) { text } }
          end

          def more(name, shown)
            left = @counts.fetch(name) - shown
            return unless left.positive?

            AutoForm(action: path(:admin_project, id: @project.id)) do
              HiddenFields(values: grown.merge(name => @sizes.fetch(name) + @step))
              Button(type: "submit", variant: :gh, small: true) { t(".load_more", count: left) }
            end
          end

          def published
            return span { IconLabel(icon: "fa-solid fa-lock") { t(".private") } } unless published?

            span(class: "kb-published") { IconLabel(icon: "fa-solid fa-globe") { t(".published") } }
          end

          def published? = @project.board_published && @project.visibility == PUBLIC

          def repo_url = (format(GITHUB, @project.repo) if written?(@project.repo))

          def site? = written?(@project.url) && @project.url != repo_url

          def tagline = written?(@project.tagline) ? @project.tagline : t(".no_tagline")
        end
      end
    end
  end
end
