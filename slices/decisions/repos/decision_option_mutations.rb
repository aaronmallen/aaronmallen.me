# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionOptionMutations < DB::Repo
      root :decision_options

      stamped_commands :create, :update
      commands delete: :by_pk
    end
  end
end
