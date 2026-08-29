# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Placement < Component
          STATUSES = {
            Blog::Types::ProjectLiveStatus["active"] => ".statuses.active",
            Blog::Types::ProjectLiveStatus["wip"] => ".statuses.wip",
            Blog::Types::ProjectLiveStatus["paused"] => ".statuses.paused",
          }.freeze

          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :archived, Blog::Types::Bool
          prop :featured, Blog::Types::Bool

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack") do
                @archived ? archived_status : status_field
                tags_field
                Toggle(label: t(".featured"), name: "project[featured]", checked: @featured)
                Hint { t(".archived_note") }
              end
            end
          end

          private

          def archived_status
            Field(label: t(".status")) do
              div { Projects::StatusPill(status: Blog::Types::ProjectStatus["archived"]) }
              Hint { t(".restore_note") }
            end
          end

          def field(name, label_key, &)
            Field(label: t(label_key), id: FieldError.id_for(name)) do
              yield
              FieldError(field: name, errors: @errors)
            end
          end

          def status_field
            field(:status, ".status") do
              Select(
                **FieldError.control_attributes(:status, @errors),
                name: "project[status]",
                options: status_options,
                selected: @values[:status],
              )
            end
          end

          def status_options = STATUSES.transform_values { t(it) }

          def tags_field
            field(:tags, ".tags") do
              Input(
                **FieldError.control_attributes(:tags, @errors),
                name: "project[tags]",
                value: @values[:tags],
                placeholder: t(".tags_placeholder"),
              )
            end
          end
        end
      end
    end
  end
end
