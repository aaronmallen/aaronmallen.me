# frozen_string_literal: true

module Admin
  module Repos
    class SessionValidityMutations < DB::Repo
      root :session_validity

      def end_sessions(at: Time.now) = session_validity.end_sessions(SessionValidityQueries::ROW_ID, at)
    end
  end
end
