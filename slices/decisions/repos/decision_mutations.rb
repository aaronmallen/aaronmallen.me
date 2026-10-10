# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionMutations < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      root :decisions

      stamped_commands :create, :update

      def by_id_for_update(id) = decisions.by_pk(id).lock.one

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)

      def replace_tags(id, names)
        decision_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
      end
    end
  end
end
