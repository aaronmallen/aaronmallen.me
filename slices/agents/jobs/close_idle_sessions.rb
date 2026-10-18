# frozen_string_literal: true

module Agents
  module Jobs
    class CloseIdleSessions < Blog::ScheduledJob
      include Deps["operations.close_idle_sessions"]

      def perform = close_idle_sessions.call
    end
  end
end
