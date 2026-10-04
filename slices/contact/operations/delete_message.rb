# frozen_string_literal: true

module Contact
  module Operations
    class DeleteMessage < Blog::Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(id) = step deleted(message_repo.delete(id))

      private

      def deleted(message) = message ? Success(message) : Failure(:not_found)
    end
  end
end
