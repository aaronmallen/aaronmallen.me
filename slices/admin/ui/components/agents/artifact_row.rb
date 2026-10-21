# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactRow < Component
          KIND = Blog::Types::RecordKind["artifact"]

          prop :artifact, Blog::Types::Instance(ROM::Struct)
          prop :current, Blog::Types::Instance(ROM::Struct)
          prop :links, Blog::Types::Integer
          prop :colors, Blog::Types::Hash

          def view_template
            div(class: "artifact-row", data: { key_row: true }) do
              RecordKey(kind: KIND, label: RecordKey.key(@artifact.id))
              div(class: "artifact-row-body") do
                a(class: "artifact-row-title", href: path(:admin_artifact, id: @artifact.id),
                  data: { key_open: true }) do
                  @artifact.title
                end
                p(class: "artifact-row-meta") { meta }
              end
            end
          end

          private

          def links
            return unless @links.positive?

            span do
              Icon("fa-solid fa-link")
              plain @links.to_s
              whitespace
              span(class: "sr-only") { t(".links", count: @links) }
            end
          end

          def meta
            ArtifactType(type: @artifact.type)
            span { t(".version", number: @current.number) }
            span { written }
            links
            ArtifactTags(tags: @artifact.tags, colors: @colors)
          end

          def written
            date = l(Blog::TimeZone.local_date(@current.created_at), format: :medium)

            t(".written", date:, who: Helpers::AgentBrand.author(@current) || t(".you"))
          end
        end
      end
    end
  end
end
