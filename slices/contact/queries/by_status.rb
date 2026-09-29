# frozen_string_literal: true

module Contact
  module Queries
    class ByStatus
      include Deps[message_repo: "repos.message_repo"]

      def call(status, page) = message_repo.page_by_status(status, page)
    end
  end
end
