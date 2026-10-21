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
              ArtifactEditor(**@editor, heading: t(".heading"), back: t(".back"))
            end
          end
        end
      end
    end
  end
end
