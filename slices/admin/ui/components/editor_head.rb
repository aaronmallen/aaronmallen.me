# frozen_string_literal: true

module Admin
  module UI
    module Components
      class EditorHead < Component
        ERROR = Blog::Types::Class.constrained(lteq: Blog::UI::FieldError)

        prop :label, Blog::Types::String
        prop :field, Blog::Types::Symbol
        prop :errors, Blog::Types::Hash
        prop :error, ERROR
        prop :attributes, Blog::Types::Hash, :**

        def below(&block)
          @below = block
          nil
        end

        def sub(&block)
          @sub = block
          nil
        end

        def view_template(&)
          vanish(&)

          header(class: "page-head") do
            div(class: "editor-head") do
              title
              p(class: "page-head-sub", &@sub) if @sub
              @below&.call
            end
            div(class: "page-head-actions", &) if block_given?
          end
        end

        private

        def title
          label(class: "sr-only", for: @error.id_for(@field)) { @label }
          input(**mix(title_attributes, @attributes))
          render @error.new(field: @field, errors: @errors)
        end

        def title_attributes = { **@error.control_attributes(@field, @errors), class: "editor-title", type: "text" }
      end
    end
  end
end
