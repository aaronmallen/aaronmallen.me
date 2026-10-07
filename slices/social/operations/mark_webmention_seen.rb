# frozen_string_literal: true

module Social
  module Operations
    class MarkWebmentionSeen < Operation
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(id, at: Time.now) = step found(webmention_repo.see(id, at))
    end
  end
end
