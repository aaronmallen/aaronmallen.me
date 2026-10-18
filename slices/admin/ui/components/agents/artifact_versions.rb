# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactVersions < Component
          prop :artifact, Blog::Types::Instance(ROM::Struct)
          prop :versions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :shown, Blog::Types::Integer

          def view_template
            Card(title: t(".title"), count: @versions.size) do
              ul(class: "record-link-list") do
                @versions.each do |version|
                  li(class: "record-link-row") do
                    row(version)
                  end
                end
              end
            end
          end

          private

          def current?(version) = version.number == @artifact.version

          def href(version)
            return path(:admin_artifact, id: @artifact.id) if current?(version)

            path(:admin_artifact, id: @artifact.id, version: version.number)
          end

          def row(version)
            div(class: "artifact-version") do
              a(class: "record-link-title", href: href(version),
                aria: { current: ("page" if version.number == @shown) }) do
                t(".version", number: version.number)
              end
              span(class: "meta") { sub(version) }
              p(class: "agent-change-text") { version.note } if version.note
            end
          end

          def sub(version)
            date = l(Blog::TimeZone.local(version.created_at), format: :medium)

            dotted(Helpers::AgentBrand.author(version) || t(".you"), date, (t(".current") if current?(version)))
          end
        end
      end
    end
  end
end
