# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Tabs < Component
          COMPLETED = Blog::Types::TaskTab["completed"]
          EXTERNAL = Blog::Types::TaskTab["external"]
          LABELS = Blog::Types::TaskTab.values.to_h { [it, ".#{it}"] }.freeze
          UNSEEN = :unseen

          prop :counts, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :query, Blog::Types::String
          prop :range, Blog::Types::Hash
          prop :saved_views, Blog::Types::Hash

          def view_template
            div(class: "screen-tabs task-tabs") do
              nav(class: "screen-tabs-list", aria: { label: t(".label") }) { LABELS.each { tab(*it) } }
              div(class: "screen-tabs-side") { SavedViews(**@saved_views) }
            end
          end

          private

          def count(name) = span(class: ["task-tab-count", ("w" if unseen?(name))]) { @counts.fetch(name).to_s }

          def href(name) = path(:admin_tasks, **params(name))

          def params(name)
            found = { filter: name }
            found[:q] = @query unless @query.empty?
            name == COMPLETED ? found.merge(@range) : found
          end

          def tab(name, label)
            current = name == @tab

            a(class: "screen-tab", href: href(name), aria: { current: ("page" if current) }) do
              span { t(label) }
              count(name)
            end
          end

          def unseen?(name) = name == EXTERNAL && @counts.fetch(UNSEEN).positive?
        end
      end
    end
  end
end
