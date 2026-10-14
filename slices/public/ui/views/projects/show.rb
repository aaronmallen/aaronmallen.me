# frozen_string_literal: true

module Public
  module UI
    module Views
      module Projects
        class Show < View
          COLUMNS = %w[backlog ready in_progress done canceled].freeze
          GITHUB = "https://github.com/"
          OPEN = Blog::Types::TaskStatus["open"]
          SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

          prop :project, Blog::Types::Instance(ROM::Struct).optional
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :sizes, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :step, Blog::Types::Integer

          def view_template
            back_link
            @project ? board : missing
          end

          private

          def back_link
            a(class: "post-back", href: path(:projects)) do
              IconLabel(icon: "fa-solid fa-arrow-left") { t(".back") }
            end
          end

          def board
            content_for(:title, t(".title", name: @project.name))
            content_for(:description,
                        written?(@project.tagline) ? @project.tagline : t(".description", name: @project.name))

            board_head
            columns = @tasks.group_by { it.status == OPEN ? it.stage : it.status }
            div(class: "board") { COLUMNS.each { column(it, columns.fetch(it, [])) } }
          end

          def board_head
            header(class: "hd") do
              span(class: "kicker") { t(".kicker") }
              h1(class: "board-name") { @project.name }
              p(class: "ld") { @project.tagline } if written?(@project.tagline)
              div(class: "board-links") { links }
            end
          end

          def card(task)
            li do
              a(class: "board-card", href: path(:project_task, slug: @project.slug, number: task.number)) do
                span(class: "board-num") { task.label }
                span(class: "board-title") { task.title }
                closed_on(task) if task.completed_at
              end
            end
          end

          def closed_on(task)
            span(class: "board-meta") do
              plain t([".closed", task.status].join("."))
              whitespace
              Moment(at: task.completed_at, format: :day)
            end
          end

          def column(key, tasks)
            section(class: ["board-col", key.tr("_", "-")]) do
              column_head(key, @counts.fetch(key))
              tasks.empty? ? p(class: "board-empty") { t(".empty") } : ul { tasks.each { card(it) } }
              more(key, tasks.size)
            end
          end

          def column_head(key, count)
            h2 do
              span(class: "board-dot", aria: { hidden: "true" })
              plain t([".columns", key].join("."))
              whitespace
              span(class: "n") { count.to_s }
            end
          end

          def grown = @sizes.reject { |_, size| size == @step }

          def link(href, text, icon)
            a(href:, rel: "noopener") { IconLabel(icon:) { text } }
          end

          def links
            repo = "#{GITHUB}#{@project.repo}" if written?(@project.repo)
            link(repo, @project.repo, "fa-brands fa-github") if repo
            link(@project.url, @project.url.sub(SCHEME, ""), "fa-solid fa-arrow-up-right-from-square") if url?(repo)
            stats
          end

          def missing
            content_for(:title, t(".missing.title"))
            content_for(:description, t(".missing.lede"))

            header(class: "hd") do
              span(class: "kicker") { t(".kicker") }
              h1 { t(".missing.heading") }
              p(class: "ld") { t(".missing.lede") }
            end
          end

          def more(key, shown)
            left = @counts.fetch(key) - shown
            return unless left.positive?

            sizes = grown.merge(key => @sizes.fetch(key) + @step).transform_keys(&:to_sym)
            a(class: "board-more", href: path(:project, slug: @project.slug, **sizes)) { t(".load_more", count: left) }
          end

          def stats
            parts = []
            parts << t(".stars", stars: Blog::Helpers::Figures.count(@project.stars)) if @project.stars.positive?
            parts << @project.release if written?(@project.release)
            span { parts.join(" · ") } unless parts.empty?
          end

          def url?(repo) = written?(@project.url) && @project.url != repo
        end
      end
    end
  end
end
