# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        module Artifacts
          class Show < View
            include Components::Agents

            KIND = Blog::Types::RecordKind["artifact"]
            LIVE_TABLES = %w[artifact_versions artifacts record_links].freeze
            RENDERER = Blog::Types::MarkdownRenderer["tasks"]

            prop :artifact, Blog::Types::Instance(ROM::Struct)
            prop :shown, Blog::Types::Instance(ROM::Struct)
            prop :versions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
            prop :records, Blog::Types::Hash

            def view_template
              content_for(:live_tables, LIVE_TABLES)
              head
              banner if old?
              div(class: "g-main") do
                Card(label: t(".body")) do
                  MarkdownBody(source: @shown.body, renderer: RENDERER, class: "markdown-body")
                end
                aside(class: "artifact-side") { side }
              end
            end

            private

            def banner
              div(class: "post-banner link-check-banner", role: "status") do
                Icon("fa-solid fa-clock-rotate-left")
                span(class: "post-banner-text") do
                  t(".old", number: @shown.number, current: @artifact.version, when: written(@shown))
                end
                ButtonForm(action: restore_path, label: t(".restore"))
                Button(href: path(:admin_artifact, id:), variant: :gh, small: true) { t(".latest") }
              end
            end

            def delete_form
              DeleteForm(
                action: path(:admin_delete_artifact, id:), label: t(".delete"),
                confirm: t(".confirm", key: RecordKey.key(id), count: @versions.size),
              )
            end

            def head
              PageHead(title: @artifact.title, kicker: RecordKey.key(id)) do
                BackLink(href: path(:admin_artifacts)) { t(".back") }
                Pill(color: nil) { @artifact.type }
                Button(href: path(:admin_edit_artifact, id:), icon: :edit) { t(".edit") }
              end
            end

            def id = @artifact.id

            def meta
              Card do
                p(class: "read-meta") do
                  span { t(".created", when: written(@versions.last)) }
                  @artifact.tags.each { |tag| span(class: "tag") { "##{tag}" } }
                end
              end
            end

            def old? = @shown.number != @artifact.version

            def restore_path = path(:admin_restore_artifact_version, id:, number: @shown.number)

            def side
              meta
              RecordLinks::Section(records: @records, kind: KIND, id:, find_path: path(:admin_artifact, id:))
              ArtifactVersions(artifact: @artifact, versions: @versions, shown: @shown.number)
              div { delete_form }
            end

            def written(version)
              t(
                ".written", date: l(Blog::TimeZone.local(version.created_at), format: :medium),
                            who: Helpers::AgentBrand.author(version) || t(".you"),
              )
            end
          end
        end
      end
    end
  end
end
