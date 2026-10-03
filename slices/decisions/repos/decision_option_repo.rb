# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionOptionRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def on_decision(decision_id, id) = decision_options.for_decision(decision_id).by_pk(id).one
    end
  end
end
