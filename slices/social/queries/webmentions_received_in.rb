# frozen_string_literal: true

module Social
  module Queries
    class WebmentionsReceivedIn
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(from:, to:, page:, status: nil, post_id: nil)
        webmention_repo.received_in(from:, to:, page:, status:, post_id:)
      end
    end
  end
end
