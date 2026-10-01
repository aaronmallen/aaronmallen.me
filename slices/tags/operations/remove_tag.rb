# frozen_string_literal: true

module Tags
  module Operations
    class RemoveTag < Blog::Operation
      include Deps[tag_repo: "repos.tag_repo"]

      def call(id, scope:)
        tag = step find(id, scope)
        step unused(tag)

        tag_repo.delete(tag.id)
      end

      private

      def find(id, scope)
        tag = tag_repo.find_in(scope, id)

        tag ? Success(tag) : Failure(:not_found)
      end

      def unused(tag)
        held = tag_repo.count_uses(tag)

        held.zero? ? Success(tag) : Failure([:in_use, held])
      end
    end
  end
end
