# frozen_string_literal: true

module Contact
  module Operations
    class MarkMessage < Blog::Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(id, status)
        message = step find(id)

        message_repo.mark(message, status)
      end

      private

      def find(id) = found(message_repo.by_id(id))
    end
  end
end
