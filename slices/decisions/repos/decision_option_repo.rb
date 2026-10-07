# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionOptionRepo < DB::Repo
      stamped_commands :create, :update
      commands delete: :by_pk

      def on_decision(decision_id, id) = decision_options.for_decision(decision_id).by_pk(id).one
    end
  end
end
