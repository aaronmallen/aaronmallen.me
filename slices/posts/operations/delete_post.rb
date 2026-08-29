# frozen_string_literal: true

module Posts
  module Operations
    class DeletePost < Blog::Operation
      include Deps[post_repo: "repos.post_repo"]

      def call(id)
        step deleted(post_repo.delete(id))
      end

      private

      def deleted(post) = post ? Success(post) : Failure(:not_found)
    end
  end
end
