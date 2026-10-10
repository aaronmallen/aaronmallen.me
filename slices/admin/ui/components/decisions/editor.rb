# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Editor < Component
          HEIGHT = "320px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :decision, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            div(class: "g-main") do
              Form(action: form_action, class: "form-stack") do
                fields
                note if closed?
                div(class: "decision-editor-acts") do
                  Button(variant: :pri, type: "submit") { t(@decision ? ".save" : ".open") }
                  Button(href: cancel_path, variant: :gh) { t(".cancel") }
                end
              end
            end
          end

          private

          def cancel_path = @decision ? path(:admin_decision, id: @decision.id) : path(:admin_decisions)

          def closed? = @decision&.closed? || false

          def fields
            Card do
              div(class: "form-stack") do
                title_field
                problem_field
                tags_field
              end
            end
          end

          def form_action = @decision ? path(:admin_update_decision, id: @decision.id) : path(:admin_create_decision)

          def note = EditNote(**note_props)

          def note_props
            { field: :note, name: "decision[note]", value: @values[:note], errors: @errors, error: FieldError,
              renderer: RENDERER, hint: t(".note_hint"), placeholder: t(".note_placeholder") }
          end

          def problem_field
            Field(label: t(".problem")) do
              MarkdownEditor(**FieldError.control_attributes(:problem, @errors), **problem_props)
              FieldError(field: :problem, errors: @errors)
            end
          end

          def problem_props
            { name: "decision[problem]", value: @values[:problem], height: HEIGHT, renderer: RENDERER,
              label: t(".problem"), placeholder: t(".problem_placeholder"), data: { edit_note_watch: "" } }
          end

          def tags_field
            Field(label: t(".tags"), name: :tags, errors: @errors, error: FieldError) do |control|
              Input(name: "decision[tags]", value: @values[:tags], placeholder: t(".tags_placeholder"), **control)
            end
          end

          def title_attributes
            { name: "decision[title]", value: @values[:title], placeholder: t(".title_placeholder"),
              autofocus: @decision.nil? }
          end

          def title_field
            Field(label: t(".title"), name: :title, errors: @errors, error: FieldError) do |control|
              Input(**title_attributes, **control)
            end
          end
        end
      end
    end
  end
end
