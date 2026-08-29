# frozen_string_literal: true

module Contact
  module Queries
    class ById
      include Deps[message_repo: "repos.message_repo"]

      def call(id) = message_repo.by_id(id)
    end
  end
end
