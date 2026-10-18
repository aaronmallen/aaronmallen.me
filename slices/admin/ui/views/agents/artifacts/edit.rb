# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        module Artifacts
          class Edit < View
            include Components::Agents

            LIVE_TABLES = %w[artifact_versions artifacts].freeze

            prop :editor, Blog::Types::Hash, :**

            def view_template
              content_for(:live_tables, LIVE_TABLES)
              artifact = @editor[:artifact]

              PageHead(title: t(".heading"), kicker: artifact.title) do
                BackLink(href: path(:admin_artifact, id: artifact.id)) { t(".back") }
              end

              ArtifactEditor(**@editor)
            end
          end
        end
      end
    end
  end
end
