# frozen_string_literal: true

module Public
  module UI
    module Components
      class SearchHit < Component
        SLUG = Blog::Types::Normalized::Slug

        prop :hit, Blog::Types::Instance(::Search::Structs::PublicHit)
        prop :board, Blog::Types::Bool

        def view_template
          li(class: "entry") do
            div(class: "entry-meta") do
              span(class: ["sq-kd", @hit.kind]) { t([".labels", @hit.kind].join(".")) }
              meta
            end
            div { body }
          end
        end

        private

        def body
          h3(class: ["entry-title", ("mono" if project?)]) { a(class: "entry-link", href:) { @hit.title } }
          excerpt
          task_line if @hit.kind == "task"
        end

        def excerpt
          p(class: "entry-blurb") do
            @hit.excerpt.each { |(text, marked)| marked ? mark { text } : plain(text) }
          end
        end

        def href
          slug = SLUG.call(@hit.project.to_s) { nil }
          return path(:post, slug: @hit.slug) if @hit.kind == "post"
          return path(:projects) unless slug && (@board || !project?)

          project? ? path(:project, slug:) : path(:project_task, slug:, number: @hit.number)
        end

        def meta
          day = @hit.day
          return Moment(at: day) if @hit.kind == "post"
          return span { t(".number", number: @hit.number) } unless project?

          span { t([".statuses", @hit.status].join(".")) }
        end

        def project? = @hit.kind == "project"

        def task_line
          p(class: "sq-t") do
            span(class: ["sq-st", @hit.status]) do
              span(class: "kd", aria: { hidden: "true" })
              plain t([".tasks", @hit.status].join("."))
            end
            span { t(".board", name: @hit.project) }
          end
        end
      end
    end
  end
end
