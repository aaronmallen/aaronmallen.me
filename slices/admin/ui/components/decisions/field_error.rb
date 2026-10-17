# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [
            ::Decisions::Contracts::DecisionCommentContract,
            ::Decisions::Contracts::DecisionContract,
            ::Decisions::Contracts::DecisionOptionContract,
            ::Decisions::Contracts::ReasonContract,
            ::Decisions::Contracts::ResolutionContract,
          ].freeze
          LIMITS = { note: { max: ::Decisions::Contracts::DecisionContract::NOTE_LIMIT } }.freeze
          SCOPE = "decision"
          OVERRIDES = { option_id: { "format" => ".option_id.missing" } }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
