# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Dialog < Component
        prop :id, Blog::Types::String.optional, default: nil
        prop :title_id, Blog::Types::String.optional, default: nil
        prop :title, Blog::Types::String.optional, default: nil
        prop :static, Blog::Types::Bool, default: false
        prop :body, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :attributes, Blog::Types::Hash, :**

        def self.opens(dialog)
          return Blog::Constants::EMPTY_HASH unless dialog

          { data: { dialog_open: dialog }, aria: { haspopup: "dialog" } }
        end

        def foot(&block)
          @foot = block
          nil
        end

        def view_template(&)
          vanish(&)

          dialog(**mix(shell_attributes, @attributes)) do
            div(class: "dialog-box") do
              head if @title
              div(**mix({ class: "dialog-body" }, @body)) { yield(self) if block_given? }
              div(class: "dialog-foot", &@foot) if @foot
            end
          end
        end

        private

        def head
          div(class: "dialog-head") do
            h2(id: title_id, class: "card-title") { @title }
            Button(
              variant: :gh, small: true, label: t(".close"), data: { dialog_close: true },
              icon: :close,
            )
          end
        end

        def shell_attributes
          {
            id: @id, class: "dialog", role: "dialog", hidden: true, data: { dialog: @static ? "static" : true },
            aria: { labelledby: (title_id if @title), modal: "true" },
          }
        end

        def title_id = @title_id || "#{@id}-title"
      end
    end
  end
end
