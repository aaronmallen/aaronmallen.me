# frozen_string_literal: true

module MCP
  module Jobs
    class ReapExpiredCredentials < Blog::ScheduledJob
      include Deps[reap_expired_credentials: "operations.reap_expired_credentials"]

      def perform = reap_expired_credentials.call
    end
  end
end
