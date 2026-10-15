# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionMutations < Blog::DB::Repo
      root :decisions

      stamped_commands :create, :update
      tagged_by :decision_tags

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)
    end
  end
end
