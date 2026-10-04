# frozen_string_literal: true

module Tags
  module Operations
    class RemoveTag < Blog::Operation
      include Deps[tag_repo: "repos.tag_repo"]

      def call(id, scope:)
        tag = step find(id, scope)

        tag_repo.delete(tag.id)
      end

      private

      def find(id, scope)
        tag = tag_repo.find_in(scope, id)

        tag ? Success(tag) : Failure(:not_found)
      end
    end
  end
end
