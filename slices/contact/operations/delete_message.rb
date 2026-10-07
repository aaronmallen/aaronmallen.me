# frozen_string_literal: true

module Contact
  module Operations
    class DeleteMessage < Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(id) = step found(message_repo.delete(id))
    end
  end
end
