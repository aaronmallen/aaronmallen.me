# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactEditor < Component
          FORM_ID = "artifact-form"
          HEIGHT = "480px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]
          TYPES = Blog::Types::ArtifactType.values.to_h { [it, it] }.freeze

          prop :artifact, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :heading, Blog::Types::String
          prop :back, Blog::Types::String

          def view_template
            PageHead(title: @heading, kicker: @artifact&.title) do
              BackLink(href: cancel_path) { @back }
              Button(href: cancel_path, variant: :gh) { t(".cancel") }
              Button(variant: :pri, type: "submit", form: FORM_ID) { save_label }
            end

            Form(action: form_action, id: FORM_ID, class: "form-stack") do
              Card { div(class: "form-stack") { meta_fields } }
              body_field
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

          def save_label = @artifact ? t(".save", number: @artifact.version + 1) : t(".create")

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
