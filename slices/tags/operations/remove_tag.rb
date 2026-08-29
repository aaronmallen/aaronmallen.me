# frozen_string_literal: true

module Tags
  module Operations
    class RemoveTag < Blog::Operation
      include Deps[tag_repo: "repos.tag_repo"]

      def call(id)
        tag = step find(id)
        step unused(tag)

        tag_repo.delete(tag.id)
      end

      private

      def find(id)
        tag = tag_repo.by_id(id)

        tag ? Success(tag) : Failure(:not_found)
      end

      def unused(tag)
        held = tag_repo.usage.fetch(tag.id, Dry::Core::Constants::EMPTY_HASH).values.sum

        held.zero? ? Success(tag) : Failure([:in_use, held])
      end
    end
  end
end
