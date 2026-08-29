# frozen_string_literal: true

module MCP
  module Jobs
    class ReapExpiredCredentials < Blog::Job
      include Deps[reap_expired_credentials: "operations.reap_expired_credentials"]

      sidekiq_options retry: false

      def perform = reap_expired_credentials.call
    end
  end
end
