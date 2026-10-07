# frozen_string_literal: true

module Admin
  module Repos
    class SessionValidityRepo < DB::Repo
      ROW_ID = 1

      def end_sessions(at: Time.now) = session_validity.end_sessions(ROW_ID, at)

      def valid_after = session_validity.by_pk(ROW_ID).one&.valid_after
    end
  end
end
