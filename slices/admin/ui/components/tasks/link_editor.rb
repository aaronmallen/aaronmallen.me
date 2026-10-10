# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class LinkEditor < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :linking, Blog::Types::Hash.optional, default: nil

          def view_template
            div(class: "task-link-editor") do
              Field(label: t(".label"), id: LinkFinder.query_id(@task)) do
                links unless @task.links.empty?
                LinkFinder(task: @task, tab: @tab, origin: @origin, linking: @linking)
              end
            end
          end

          private

          def links
            div(class: "task-link-list") do
              @task.links.each { LinkRow(task: @task, link: it, tab: @tab, origin: @origin) }
            end
          end
        end
      end
    end
  end
end
