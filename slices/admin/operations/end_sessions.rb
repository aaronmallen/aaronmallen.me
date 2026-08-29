# frozen_string_literal: true

module Admin
  module Operations
    class EndSessions < Blog::Operation
      include Deps[session_validity_repo: "repos.session_validity_repo"]

      def call = session_validity_repo.end_sessions
    end
  end
end
