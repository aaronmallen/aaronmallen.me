# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TimeReport
        class Row < Component
          DAY = Blog::Types::TimeGrouping["day"]
          NONE = { "project" => ".no_project", "tag" => ".no_tag" }.freeze

          prop :group, Blog::Types::Instance(::Tasks::Structs::TimeGroup)
          prop :by, Blog::Types::TimeGrouping
          prop :top, Blog::Types::Integer

          def view_template
            details(class: "time-group") do
              summary(class: "time-row") { head }
              div(class: "time-tasks") { @group.tasks.each { task(it) } }
            end
          end

          private

          def head
            Icon("fa-solid fa-chevron-right time-caret")
            span(class: "meter-name") { name }
            shared if @group.shared
            meter
            span(class: "meter-count") { Blog::Figures.hours(@group.seconds) }
          end

          def meter
            span(class: "meter blue") do
              span(class: "meter-fill", style: "width: #{Blog::Figures.share(@group.seconds, @top)}%")
            end
          end

          def name
            return t(NONE.fetch(@by)) if @group.key.nil?

            @by == DAY ? l(@group.key, format: :weekday) : @group.name
          end

          def shared = Pill(color: :orange) { t(".shared") }

          def task(found)
            ListItem(title: found.title, href: path(:admin_task, id: found.id)) do
              shared if found.shared
              span(class: "time-task-hours") { Blog::Figures.hours(found.seconds) }
            end
          end
        end
      end
    end
  end
end
