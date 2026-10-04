# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SavedView < Component
        prop :view, Blog::Types::Instance(ROM::Struct)
        prop :href, Blog::Types::String
        prop :current, Blog::Types::Bool
        prop :return_to, Blog::Types::String
        prop :filters, Blog::Types::Hash

        def view_template
          li(class: "saved-view") do
            a(
              class: ["saved-view-link", ("current" if @current)], href: @href, aria: { current: ("page" if @current) },
            ) { @view.name }
            SavedViewMenu(label: t(".manage", view: @view.name), icon: "fa-solid fa-ellipsis", quiet: true) do
              rename
              div(class: "saved-view-acts") do
                change
                delete
              end
            end
          end
        end

        private

        def act(route, icon, label, variant: nil, data: nil, filters: Blog::Constants::EMPTY_HASH)
          Form(action: path(route, id: @view.id), data:) do
            SavedViewFields(return_to: @return_to, filters:)
            Button(type: "submit", variant:, small: true) do
              i(class: icon, aria: { hidden: "true" })
              span { label }
            end
          end
        end

        def change = act(:admin_change_saved_view, "fa-solid fa-arrows-rotate", t(".change"), filters: @filters)

        def delete
          confirm = { confirm: t(".confirm_delete", view: @view.name), confirm_styled: true }

          act(:admin_delete_saved_view, "fa-regular fa-trash-can", t(".delete"), variant: :warn, data: confirm)
        end

        def rename
          Form(action: path(:admin_update_saved_view, id: @view.id), class: "saved-view-form") do
            SavedViewFields(return_to: @return_to)
            SavedViewName(id: "saved-view-#{@view.id}-name", value: @view.name, submit: t(".rename"))
          end
        end
      end
    end
  end
end
