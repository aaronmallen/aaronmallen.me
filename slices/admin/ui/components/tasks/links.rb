# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Links < Component
          ICONS = {
            "blocks" => "fa-solid fa-arrow-right-long",
            "blocked_by" => "fa-solid fa-lock",
            "child_of" => "fa-solid fa-arrow-turn-up",
            "duplicates" => "fa-regular fa-clone",
            "duplicated_by" => "fa-regular fa-clone",
            "parent_of" => "fa-solid fa-sitemap",
            "relates" => "fa-solid fa-link",
          }.freeze
          CLOSED = Blog::Types::ClosedTaskStatus
          LABELS = "ui.components.tasks.links.labels"

          prop :links, Blog::Types::Array.of(Blog::Types::Instance(Data))

          def self.label_key(link) = [LABELS, link.label].join(".")

          def view_template
            @links.each { chip(it) }
          end

          private

          def chip(link)
            span(class: chip_class(link), title: link.task.title) do
              Icon(ICONS.fetch(link.label))
              span(class: "task-link-label") { t(self.class.label_key(link)) }
              RecordKey(kind: "task", id: link.task.id)
              span(class: "sr-only") { link.task.title }
            end
          end

          def chip_class(link)
            ["task-link", ("blocker" if link.blocker?), ("done" if CLOSED.valid?(link.task.status))]
          end
        end
      end
    end
  end
end
