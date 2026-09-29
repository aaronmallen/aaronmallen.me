# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Links < Component
          ICONS = {
            "blocks" => "fa-solid fa-arrow-right-long",
            "blocked_by" => "fa-solid fa-lock",
            "duplicates" => "fa-regular fa-clone",
            "duplicated_by" => "fa-regular fa-clone",
            "relates" => "fa-solid fa-link",
          }.freeze
          CLOSED = [Blog::Types::TaskStatus["canceled"], Blog::Types::TaskStatus["done"]].freeze
          LABELS = "ui.components.tasks.links.labels"

          prop :links, Blog::Types::Array.of(Blog::Types::Instance(Data))
          prop :types, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def self.label_key(link) = [LABELS, link.label].join(".")

          def view_template
            div(class: "task-links") { @links.each { chip(it) } }
          end

          private

          def chip(link)
            span(class: chip_class(link)) do
              i(class: ICONS.fetch(link.label), aria: { hidden: "true" })
              span(class: "task-link-label") { t(self.class.label_key(link)) }
              TaskKey(task: link.task, type: type_of(link.task))
              span(class: "task-link-title") { link.task.title }
            end
          end

          def chip_class(link)
            ["task-link", ("blocker" if link.blocker?), ("done" if CLOSED.include?(link.task.status))]
          end

          def type_of(task) = @types.find { it.id == task.task_type_id }
        end
      end
    end
  end
end
