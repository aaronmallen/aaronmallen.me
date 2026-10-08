# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Dialog < Component
        prop :id, Blog::Types::String.optional, default: nil
        prop :title_id, Blog::Types::String
        prop :title, Blog::Types::String.optional, default: nil
        prop :title_data, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :attributes, Blog::Types::Hash, :**

        def foot(&block)
          @foot = block
          nil
        end

        def view_template(&)
          vanish(&)

          dialog(**mix(shell_attributes, @attributes)) do
            div(class: "dialog-box") do
              head if @title
              div(class: "dialog-body") { yield(self) if block_given? }
              div(class: "dialog-foot", &@foot) if @foot
            end
          end
        end

        private

        def head
          div(class: "dialog-head") do
            h2(id: @title_id, class: "card-title", data: @title_data) { @title }
            Button(
              variant: :gh, small: true, aria: { label: t(".close") }, data: { dialog_close: true },
              icon: "fa-solid fa-xmark",
            )
          end
        end

        def shell_attributes
          { id: @id, class: "dialog", role: "dialog", hidden: true, aria: { labelledby: @title_id, modal: "true" } }
        end
      end
    end
  end
end
