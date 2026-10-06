# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class OptionForm < Component
          HEIGHT = "160px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]
          SAVED = %i[title body].freeze

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :option, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop :params, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            Form(action: form_action, class: "task-comment-form") do
              title_field
              body_field
              note if noted?
              Button(variant: :pri, type: "submit", small: true) { t(@option ? ".save" : ".add") }
            end
          end

          private

          def body_field
            Field(label: t(".body")) do
              MarkdownEditor(**FieldError.control_attributes(:body, @errors, scope), **body_props)
              FieldError(field: :body, errors: @errors, scope:)
            end
          end

          def body_props
            { name: "option[body]", value: value(:body), height: HEIGHT, renderer: RENDERER, label: t(".body"),
              placeholder: t(".body_placeholder"), **watch }
          end

          def form_action
            return path(:admin_create_decision_option, id: @decision.id) unless @option

            path(:admin_update_decision_option, id: @decision.id, option_id: @option.id)
          end

          def note
            EditNote(name: "option[note]", scope:, value: value(:note), errors: @errors)
          end

          def noted? = @option && @decision.closed?

          def scope = "decision-option-#{@option ? @option.id : 'new'}"

          def title_attributes
            {
              name: "option[title]",
              value: value(:title),
              placeholder: t(".title_placeholder"),
              **watch,
            }
          end

          def title_field
            Field(label: t(".title"), name: :title, errors: @errors, error: FieldError, scope:) do |control|
              Input(**control, **title_attributes)
            end
          end

          def value(field)
            return Blog::Types::Text[@params[field]] if @params
            return Blog::Constants::EMPTY_STRING unless @option && SAVED.include?(field)

            @option.public_send(field)
          end

          def watch = noted? ? { data: { edit_note_watch: "" } } : Blog::Constants::EMPTY_HASH
        end
      end
    end
  end
end
