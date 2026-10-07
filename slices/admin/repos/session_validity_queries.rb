# frozen_string_literal: true

module Admin
  module Repos
    class SessionValidityQueries < DB::Repo
      ROW_ID = 1

      def valid_after = session_validity.by_pk(ROW_ID).one&.valid_after
    end
  end
end
