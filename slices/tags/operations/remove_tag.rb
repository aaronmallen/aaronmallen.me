# frozen_string_literal: true

module Tags
  module Operations
    class RemoveTag < Blog::Operation
      LAST_TAG = "task_tag_rules_last_tag"

      include Deps[tag_repo: "repos.tag_repo"]

      def call(id, scope:)
        tag = step find(id, scope)

        step delete(tag)
      end

      private

      def delete(tag)
        Success(transaction { tag_repo.delete(tag.id) })
      rescue ROM::SQL::CheckConstraintError => e
        raise unless tag_repo.violated_constraint(e) == LAST_TAG

        Failure([:last_tag_of_rules, tag_repo.last_tag_of_rules(tag.id)])
      end

      def find(id, scope)
        found(tag_repo.find_in(scope, id))
      end
    end
  end
end
