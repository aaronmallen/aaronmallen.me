# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Tabs < Component
          LABELS = {
            Blog::Types::TaskTab["today"] => ".today",
            Blog::Types::TaskTab["upcoming"] => ".upcoming",
            Blog::Types::TaskTab["next"] => ".next",
            Blog::Types::TaskTab["someday"] => ".someday",
            Blog::Types::TaskTab["external"] => ".external",
            Blog::Types::TaskTab["completed"] => ".completed",
          }.freeze
          EXTERNAL = Blog::Types::TaskTab["external"]
          NAMES = Blog::Types::TaskTab.values.freeze
          UNSEEN = :unseen

          prop :counts, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :query, Blog::Types::String
          prop :saved_views, Blog::Types::Hash

          def view_template
            div(class: "screen-tabs task-tabs") do
              nav(class: "screen-tabs-list", aria: { label: t(".label") }) { NAMES.each { tab(it) } }
              div(class: "screen-tabs-side") { SavedViews(**@saved_views) }
            end
          end

          private

          def count(name) = span(class: ["task-tab-count", ("w" if unseen?(name))]) { @counts.fetch(name).to_s }

          def href(name) = path(:admin_tasks, **params(name))

          def params(name)
            found = { filter: name }
            found[:q] = @query unless @query.empty?
            found
          end

          def tab(name)
            current = name == @tab

            a(class: "screen-tab", href: href(name), aria: { current: ("page" if current) }) do
              span { t(LABELS.fetch(name)) }
              count(name)
            end
          end

          def unseen?(name) = name == EXTERNAL && @counts.fetch(UNSEEN).positive?
        end
      end
    end
  end
end
