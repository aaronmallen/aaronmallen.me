# frozen_string_literal: true

module Public
  module UI
    module Components
      class BoardTask < Component
        KINDS = { card: "board", row: "board-row" }.freeze

        prop :task, Blog::Types::Instance(ROM::Struct)
        prop :project, Blog::Types::Instance(ROM::Struct)
        prop :kind, Blog::Types::Symbol.enum(*KINDS.keys)
        prop :query, Blog::Types::String

        def view_template
          tags = @task.tags.select { it.project_id == @project.id }
          li(class: ("board-item" if @kind == :card)) do
            link
            tag_line(tags) if tags.any?
          end
        end

        private

        def closed_on
          span(class: part("meta")) do
            plain t([".closed", @task.status].join("."))
            whitespace
            Moment(at: @task.completed_at, format: :day)
          end
        end

        def href = path(:project_task, slug: @project.slug, number: @task.number)

        def labelled(tag)
          term = "label:#{tag.name}"
          q = @query.split.include?(term) ? @query : [@query, term].join(" ").strip
          path(:project, slug: @project.slug, q:)
        end

        def link
          a(class: @kind == :card ? "board-card" : "board-row", href:) do
            span(class: part("num")) { @task.label }
            span(class: part("title")) { @task.title }
            closed_on if @task.completed_at
          end
        end

        def part(name) = "#{KINDS.fetch(@kind)}-#{name}"

        def tag_line(tags)
          p(class: part("tags")) do
            tags.each do |tag|
              a(class: ["tag", Blog::UI::Components::Pill.for_tag_color(tag.color)&.to_s], href: labelled(tag)) do
                "##{tag.name}"
              end
            end
          end
        end
      end
    end
  end
end
