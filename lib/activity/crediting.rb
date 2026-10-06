# frozen_string_literal: true

module Activity
  module Crediting
    KINDS = Blog::Types::ContributorKind.values.freeze

    def credited(contributors: [], agents: [], models: [])
      return none if unmatchable?(agents, models) || (contributors - KINDS).any?

      terms = [*contributors.map { { kind: it } }, *agents.map { { agent: it } }, *models.map { { model: it } }]
      terms.empty? ? self : where(self[:contributors].contain(terms))
    end
  end
end
