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
              ArtifactEditor(**@editor, heading: t(".heading"), back: t(".back"))
            end
          end
        end
      end
    end
  end
end
