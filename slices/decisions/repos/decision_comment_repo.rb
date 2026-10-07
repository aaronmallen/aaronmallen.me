# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionCommentRepo < DB::Repo
      stamped_commands :create, :update

      def delete_on_decision(decision_id, id) = on_decision(decision_id, id).delete

      def oldest_first(decision_id) = decision_comments.for_decision(decision_id).oldest_first.to_a

      def on_decision?(decision_id, id) = on_decision(decision_id, id).exist?

      private

      def on_decision(decision_id, id) = decision_comments.for_decision(decision_id).by_pk(id)
    end
  end
end
