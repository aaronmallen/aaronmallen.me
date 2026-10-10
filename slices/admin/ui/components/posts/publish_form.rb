# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class PublishForm < Component
          KEY = "p"

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer

          def view_template
            Form(action: path(:admin_publish_post, id: @post.id)) do
              input(type: "hidden", name: "status", value: @filter)
              HiddenFields(values: Blog::Structs::Page.query(@page))
              button
            end
          end

          private

          def button
            label = t(".publish", title: @post.title)
            aria = { keyshortcuts: KEY }

            Button(
              type: "submit", small: true, label:, aria:, data: { key: KEY, key_label: t(".key") },
              icon: "fa-solid fa-arrow-up-right-from-square",
            )
          end
        end
      end
    end
  end
end
