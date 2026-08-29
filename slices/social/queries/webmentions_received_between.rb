# frozen_string_literal: true

module Social
  module Queries
    class WebmentionsReceivedBetween
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(from:, to:) = webmention_repo.received_between(from:, to:)
    end
  end
end
