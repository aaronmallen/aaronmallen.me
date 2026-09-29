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
          BLOCKED_BY = "blocked_by"
          CLOSED = [Blog::Types::TaskStatus["canceled"], Blog::Types::TaskStatus["done"]].freeze
          LABELS = "ui.components.tasks.links.labels"

          prop :links, Blog::Types::Array.of(Blog::Types::Instance(Data))

          def self.label_key(link) = [LABELS, link.label].join(".")

          def view_template
            div(class: "task-links") { @links.each { chip(it) } }
          end

          private

          def chip(link)
            span(class: chip_class(link), title: (link.task.title if key_only?(link))) do
              i(class: ICONS.fetch(link.label), aria: { hidden: "true" })
              span(class: "task-link-label") { t(self.class.label_key(link)) }
              TaskKey(task: link.task)
              chip_title(link)
            end
          end

          def chip_class(link)
            ["task-link", ("blocker" if link.blocker?), ("done" if CLOSED.include?(link.task.status))]
          end

          def chip_title(link)
            span(class: key_only?(link) ? "sr-only" : "task-link-title") { link.task.title }
          end

          def key_only?(link) = link.label == BLOCKED_BY
        end
      end
    end
  end
end
