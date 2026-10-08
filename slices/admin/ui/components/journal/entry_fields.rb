# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class EntryFields < Component
          prop :body, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :errors, Blog::Types::Hash
          prop :height, MarkdownEditor::HEIGHT
          prop :label, Blog::Types::String
          prop :scope, Blog::Types::String, default: FieldError::SCOPE
          prop :placeholder, Blog::Types::String.optional, default: nil
          prop :autofocus, Blog::Types::Bool, default: false
          prop :only, Blog::Types::Symbol.enum(:body, :tags).optional, default: nil

          def self.blank?(body) = !body.match?(/\S/)

          def view_template
            body_field unless @only == :tags
            tags_field unless @only == :body
          end

          private

          def body_field
            div(class: "journal-editor") { MarkdownEditor(**body_props) }
            FieldError(field: :body, errors: @errors, scope: @scope)
          end

          def body_props
            {
              **FieldError.control_attributes(:body, @errors, @scope),
              name: "entry[body]", value: @body, height: @height, renderer: "posts", label: @label,
              placeholder: @placeholder, autofocus: @autofocus, data: { journal_body: "" },
            }
          end

          def tags_field
            label(class: "sr-only", for: FieldError.id_for(:tags, @scope)) { t(".tags") }
            Input(
              **FieldError.control_attributes(:tags, @errors, @scope),
              name: "entry[tags]",
              value: @tags,
              placeholder: t(".tags_placeholder"),
            )
            FieldError(field: :tags, errors: @errors, scope: @scope)
          end
        end
      end
    end
  end
end
