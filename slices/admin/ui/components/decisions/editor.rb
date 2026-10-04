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
            Form(action: form_action, class: "form-stack") do
              fields
              note if closed?
              div { Button(variant: :pri, type: "submit") { t(@decision ? ".save" : ".open") } }
            end
          end

          private

          def closed? = @decision&.closed? || false

          def fields
            Card(label: t(".label"), title: t(@decision ? ".edit_title" : ".new_title")) do
              div(class: "form-stack") do
                title_field
                problem_field
                tags_field
              end
            end
          end

          def form_action = @decision ? path(:admin_update_decision, id: @decision.id) : path(:admin_create_decision)

          def note = EditNote(name: "decision[note]", scope: FieldError::SCOPE, value: @values[:note], errors: @errors)

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
            Field(label: t(".tags"), id: FieldError.id_for(:tags)) do
              Input(
                name: "decision[tags]", value: @values[:tags], placeholder: t(".tags_placeholder"),
                **FieldError.control_attributes(:tags, @errors),
              )
              FieldError(field: :tags, errors: @errors)
            end
          end

          def title_attributes
            { name: "decision[title]", value: @values[:title], placeholder: t(".title_placeholder"),
              autofocus: @decision.nil?, **FieldError.control_attributes(:title, @errors) }
          end

          def title_field
            Field(label: t(".title"), id: FieldError.id_for(:title)) do
              Input(**title_attributes)
              FieldError(field: :title, errors: @errors)
            end
          end
        end
      end
    end
  end
end
