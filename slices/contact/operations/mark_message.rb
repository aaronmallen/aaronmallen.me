# frozen_string_literal: true

module Contact
  module Operations
    class MarkMessage < Blog::Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(id, status)
        step find(id)

        message_repo.update(id, status:)
      end

      private

      def find(id) = message_repo.by_id(id) ? Success(id) : Failure(:not_found)
    end
  end
end
