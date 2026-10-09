# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Field < Component
        ERROR = Blog::Types::Class.constrained(lteq: Blog::UI::FieldError)

        prop :label, Blog::Types::String
        prop :id, Blog::Types::String.optional, default: nil
        prop :name, Blog::Types::Symbol.optional, default: nil
        prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
        prop :error, ERROR.optional, default: nil
        prop :scope, Blog::Types::String.optional, default: nil
        prop :icon, Blog::Types::String.optional, default: nil
        prop :attributes, Blog::Types::Hash, :**

        def after(&block)
          @after = block
          nil
        end

        def view_template(&)
          div(**mix({ class: "field" }, @attributes)) do
            render_label
            yield control, self
            render @error.new(field: @name, errors: @errors, scope:) if @name
            @after&.call
          end
        end

        private

        def control
          return @error.control_attributes(@name, @errors, scope) if @name
          return Blog::Constants::EMPTY_HASH unless @id

          { id: @id }
        end

        def control_id = @name ? @error.id_for(@name, scope) : @id

        def label_text
          i(class: "#{@icon} f-icon", aria: { hidden: "true" }) if @icon
          plain @label
        end

        def render_label
          id = control_id
          return span(class: "f") { label_text } unless id

          label(class: "f", for: id) { label_text }
        end

        def scope = @scope || @error::SCOPE
      end
    end
  end
end
