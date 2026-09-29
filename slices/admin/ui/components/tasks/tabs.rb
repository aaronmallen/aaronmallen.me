# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Tabs < Component
          ICONS = {
            Blog::Types::TaskTab["today"] => "fa-solid fa-sun",
            Blog::Types::TaskTab["upcoming"] => "fa-regular fa-calendar",
            Blog::Types::TaskTab["completed"] => "fa-solid fa-circle-check",
          }.freeze
          LABELS = {
            Blog::Types::TaskTab["today"] => ".today",
            Blog::Types::TaskTab["upcoming"] => ".upcoming",
            Blog::Types::TaskTab["next"] => ".next",
            Blog::Types::TaskTab["someday"] => ".someday",
            Blog::Types::TaskTab["completed"] => ".completed",
          }.freeze
          NAMES = Blog::Types::TaskTab.values.freeze

          prop :counts, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :query, Blog::Types::String

          def view_template
            nav(class: "subtabs", aria: { label: t(".label") }) do
              NAMES.each { tab(it) }
            end
          end

          private

          def count(name) = span(class: "subtab-count") { @counts.fetch(name).to_s }

          def href(name) = path(:admin_tasks, **params(name))

          def icon(name)
            found = ICONS[name]

            i(class: found, aria: { hidden: "true" }) if found
          end

          def params(name)
            found = { filter: name }
            found[:q] = @query unless @query.empty?
            found
          end

          def tab(name)
            current = name == @tab

            a(class: ["subtab", ("on" if current)], href: href(name), aria: { current: ("page" if current) }) do
              icon(name)
              span { t(LABELS.fetch(name)) }
              count(name)
            end
          end
        end
      end
    end
  end
end
