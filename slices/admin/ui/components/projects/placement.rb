# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Placement < Component
          VISIBILITIES = {
            Blog::Constants::EMPTY_STRING => ".visibilities.unset",
            **Blog::Types::ProjectVisibility.values.to_h { [it, ".visibilities.#{it}"] },
          }.freeze

          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :archived, Blog::Types::Bool

          def view_template
            Card(title: t(".heading")) do
              div(class: "form-stack") do
                visibility_field
                archived_status if @archived
                tags_field
              end
            end
          end

          private

          def archived_status
            Field(label: t(".status")) do
              div { StatusPill(status: :archived) }
              Hint { t(".restore_note") }
            end
          end

          def tags_field
            Field(label: t(".tags"), name: :tags, errors: @errors, error: FieldError) do |control|
              Input(
                **control,
                name: "project[tags]",
                value: @values[:tags],
                placeholder: t(".tags_placeholder"),
              )
            end
          end

          def visibility_field
            Field(label: t(".visibility"), name: :visibility, errors: @errors, error: FieldError) do |control|
              Select(
                **control,
                name: "project[visibility]",
                options: VISIBILITIES.transform_values { t(it) },
                selected: @values[:visibility],
                required: true,
              )
            end
          end
        end
      end
    end
  end
end
