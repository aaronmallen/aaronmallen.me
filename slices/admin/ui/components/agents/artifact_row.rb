# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactRow < Component
          prop :artifact, Blog::Types::Instance(ROM::Struct)
          prop :current, Blog::Types::Instance(ROM::Struct)
          prop :links, Blog::Types::Integer

          def view_template
            ListItem(title: @artifact.title, href: path(:admin_artifact, id: @artifact.id), sub:) do
              span(class: "mono") { RecordKey.key(@artifact.id) }
            end
          end

          private

          def sub
            dotted(
              @artifact.type, t(".version", number: @current.number), written,
              (t(".links", count: @links) if @links.positive?), *@artifact.tags.map { "##{it}" },
            )
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
