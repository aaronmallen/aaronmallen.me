# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionMutations < Blog::DB::Repo
      root :decisions

      stamped_commands :create, :update

      def add_tag(id, name)
        update(id, {}) unless decision_tags.tag(id, [name], tags).empty?
      end

      def by_id_for_update(id) = decisions.by_pk(id).lock.one

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)

      def remove_tag(id, name)
        update(id, {}) if decision_tags.untag(id, [name], tags).positive?
      end

      def replace_tags(id, names) = decision_tags.retag(id, names, tags)
    end
  end
end
