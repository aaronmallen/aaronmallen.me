# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactEditor < Component
          HEIGHT = "480px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]
          TYPES = Blog::Types::ArtifactType.values.to_h { [it, it] }.freeze

          prop :artifact, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            Form(action: form_action, class: "form-stack") do
              Card { div(class: "form-stack") { meta_fields } }
              body_field
              div(class: "artifact-acts") do
                Button(variant: :pri, type: "submit") { save_label }
                Button(href: cancel_path, variant: :gh) { t(".cancel") }
              end
            end
          end

          private

          def body_field
            MarkdownEditor(
              field: :body, errors: @errors, error: ArtifactFieldError, name: "artifact[body]", value: @values[:body],
              height: HEIGHT, renderer: RENDERER, label: t(".body"), placeholder: t(".body_placeholder"), split: true,
            ) { MarkdownBody(source: @values[:body], renderer: RENDERER, class: "markdown-body") }
          end

          def cancel_path = @artifact ? path(:admin_artifact, id: @artifact.id) : path(:admin_artifacts)

          def field(name, label, &) = Field(label:, name:, errors: @errors, error: ArtifactFieldError, &)

          def form_action = @artifact ? path(:admin_update_artifact, id: @artifact.id) : path(:admin_create_artifact)

          def meta_fields
            title_field
            div(class: "artifact-meta") do
              type_field
              tags_field
            end
            note_field if @artifact
          end

          def note_attributes
            { placeholder: t(".note_placeholder"), maxlength: ArtifactFieldError::CONTRACT::NOTE_LIMIT }
          end

          def note_field
            field(:note, t(".note")) do |control|
              Input(**control, name: "artifact[note]", value: @values[:note], **note_attributes)
            end
          end

          def save_label = t(@artifact ? ".save" : ".create")

          def tags_field
            field(:tags, t(".tags")) do |control|
              Input(**control, name: "artifact[tags]", value: @values[:tags], placeholder: t(".tags_placeholder"))
            end
          end

          def title_attributes = { placeholder: t(".title_placeholder"), autofocus: @artifact.nil? }

          def title_field
            field(:title, t(".title")) do |control|
              Input(**control, name: "artifact[title]", value: @values[:title], **title_attributes)
            end
          end

          def type_field
            field(:type, t(".type")) do |control|
              Select(**control, name: "artifact[type]", options: TYPES, selected: @values[:type])
            end
          end
        end
      end
    end
  end
end
