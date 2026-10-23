# frozen_string_literal: true

module Public
  module UI
    module Views
      module Projects
        class Show < View
          prop :project, Blog::Types::Instance(ROM::Struct).optional
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :board, Blog::Types::Instance(Blog::BoardSizes)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :filter, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

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
            views
          end

          def board_head
            header(class: "hd") do
              span(class: "kicker") { t(".kicker") }
              h1(class: "board-name") { @project.name }
              p(class: "ld") { @project.tagline } if written?(@project.tagline)
              div(class: "board-links") { links }
            end
          end

          def column(key, tasks)
            section(class: ["board-col", key.tr("_", "-")]) do
              h2 { column_head(key) }
              tasks.empty? ? p(class: "board-empty") { t(".empty") } : ul { tasks.each { task(it, :card) } }
              more(key, tasks.size, "board")
            end
          end

          def column_head(key)
            span(class: "board-dot", aria: { hidden: "true" })
            plain t([".columns", key].join("."))
            whitespace
            span(class: "n") { @counts.fetch(key).to_s }
          end

          def filtered = { q: @filter[:text] }.reject { |_, text| text.empty? }

          def group(key, tasks)
            details(class: ["board-group", key.tr("_", "-")], open: key != "canceled") do
              summary do
                Icon("fa-solid fa-chevron-right")
                column_head(key)
              end
              tasks.empty? ? p(class: "board-empty") { t(".empty") } : ul { tasks.each { task(it, :row) } }
              more(key, tasks.size, "list")
            end
          end

          def link(href, text, icon)
            a(href:, rel: "noopener") { IconLabel(icon:) { text } }
          end

          def links
            repo = @project.repo_url
            link(repo, @project.repo, Blog::Constants::GITHUB_ICON) if repo
            link(@project.url, bare_url(@project.url), :outbound) if url?(repo)
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

          def more(key, shown, view)
            left = @board.left(@counts.fetch(key), shown)
            return unless left.positive?

            a(class: "board-more", href: path(:project, slug: @project.slug, **@board.more(key), **filtered, view:)) do
              t("ui.board.load_more", count: left)
            end
          end

          def stats
            stars = t(".stars", stars: Blog::Helpers::Figures.count(@project.stars)) if @project.stars.positive?
            line = dotted(stars, @project.release)
            span { line } unless line.empty?
          end

          def task(task, kind) = BoardTask(task:, kind:, project: @project, query: @filter[:text])

          def url?(repo) = written?(@project.url) && @project.url != repo

          def views
            columns = Blog::Types::TaskColumn.values.to_h { [it, []] }.merge(@tasks.group_by(&:board_column))
            BoardFilter(project: @project, tags: @tags, filter: @filter, shown: @counts.values.sum)
            div(class: "board-views", data: { board_views: "" }) do
              BoardBar(counts: @counts)
              div(class: "board") { columns.each { |key, tasks| column(key, tasks) } }
              div(class: "board-list") { columns.each { |key, tasks| group(key, tasks) } }
            end
          end
        end
      end
    end
  end
end
