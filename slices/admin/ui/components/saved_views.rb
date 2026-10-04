# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      class SavedViews < Component
        SCREENS = {
          Blog::Types::SavedViewScreen["activity"] => :admin_activity,
          Blog::Types::SavedViewScreen["journal"] => :admin_journal,
          Blog::Types::SavedViewScreen["posts"] => :admin_posts,
          Blog::Types::SavedViewScreen["tasks"] => :admin_tasks,
        }.freeze

        prop :screen, Blog::Types::SavedViewScreen
        prop :views, Blog::Types::Array
        prop :filters, Blog::Types::Hash

        def self.href(base, filters)
          query = ::Rack::Utils.build_nested_query(filters)

          query.empty? ? base : "#{base}?#{query}"
        end

        def view_template
          div(class: "saved-views", role: "group", aria: { label: t(".label") }) do
            ul(class: "saved-views-list") { @views.each { item(it) } } unless @views.empty?
            creator
          end
        end

        private

        def creator
          SavedViewMenu(label: t(".save"), icon: "fa-regular fa-bookmark") do
            Form(action: path(:admin_create_saved_view), class: "saved-view-form") do
              SavedViewFields(return_to:, filters: @filters)
              input(type: "hidden", name: "screen", value: @screen)
              SavedViewName(id: "saved-view-new-name", submit: t(".save"))
            end
          end
        end

        def current?(view) = view.filters.reject { |_, value| value.empty? } == @filters

        def item(view)
          SavedView(view:, href: screen_path(view.filters), current: current?(view), return_to:, filters: @filters)
        end

        def return_to = screen_path(@filters)

        def screen_path(filters) = self.class.href(path(SCREENS.fetch(@screen)), filters)
      end
    end
  end
end
