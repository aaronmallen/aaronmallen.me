# frozen_string_literal: true

module Social
  module Queries
    class WebmentionsReceivedByPost
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(from:, to:) = webmention_repo.received_by_post(from:, to:)
    end
  end
end
