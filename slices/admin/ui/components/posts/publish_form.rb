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
              Blog::Page.query(@page).each { |name, value| input(type: "hidden", name:, value:) }
              button
            end
          end

          private

          def button
            label = t(".publish", title: @post.title)
            aria = { label:, keyshortcuts: KEY }

            Button(type: "submit", small: true, title: label, aria:, data: { key: KEY, key_label: t(".key") }) do
              i(class: "fa-solid fa-arrow-up-right-from-square", aria: { hidden: "true" })
            end
          end
        end
      end
    end
  end
end
