# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactFieldError < Blog::UI::FieldError
          CONTRACT = ::Agents::Contracts::ArtifactContract
          CONTRACTS = [CONTRACT].freeze
          LIMITS = {
            title: { max: CONTRACT::TITLE_LIMIT }, body: { max: CONTRACT::BODY_LIMIT },
            note: { max: CONTRACT::NOTE_LIMIT },
          }.freeze
          SCOPE = "artifact"
          UNSHOWN = %i[agent model session_id].freeze
        end
      end
    end
  end
end
