# frozen_string_literal: true

module Admin
  module Operations
    class EndSessions < Operation
      include Deps["repos.session_validity_mutations"]

      def call = session_validity_mutations.end_sessions
    end
  end
end
