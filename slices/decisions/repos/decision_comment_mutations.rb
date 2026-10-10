# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionCommentMutations < Blog::DB::Repo
      root :decision_comments

      stamped_commands :create, :update

      def delete_on_decision(decision_id, id) = decision_comments.for_decision(decision_id).by_pk(id).delete
    end
  end
end
