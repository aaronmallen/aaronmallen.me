# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        module Artifacts
          class New < View
            include Components::Agents

            prop :editor, Blog::Types::Hash, :**

            def view_template
              content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
              PageHead(title: t(".heading")) do
                BackLink(href: path(:admin_artifacts)) { t(".back") }
              end

              ArtifactEditor(**@editor)
            end
          end
        end
      end
    end
  end
end
