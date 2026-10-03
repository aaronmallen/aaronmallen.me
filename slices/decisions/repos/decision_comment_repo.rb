# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionCommentRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def delete_on_decision(decision_id, id) = on_decision(decision_id, id).delete

      def on_decision?(decision_id, id) = on_decision(decision_id, id).exist?

      private

      def on_decision(decision_id, id) = decision_comments.for_decision(decision_id).by_pk(id)
    end
  end
end
