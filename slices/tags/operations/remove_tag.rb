# frozen_string_literal: true

module Tags
  module Operations
    class RemoveTag < Blog::Operation
      LAST_TARGET = "task_rules_last_target"

      include Deps[tag_mutations: "repos.tag_mutations", tag_queries: "repos.tag_queries"]

      def call(id, scope:)
        tag = step find(id, scope)

        step delete(tag)
      end

      private

      def delete(tag)
        Success(transaction { tag_mutations.delete(tag.id) })
      rescue ROM::SQL::CheckConstraintError => e
        raise unless tag_mutations.violated_constraint(e) == LAST_TARGET

        Failure([:last_tag_of_rules, tag_queries.last_tag_of_rules(tag.id)])
      end

      def find(id, scope)
        found(tag_queries.find_in(scope, id))
      end
    end
  end
end
