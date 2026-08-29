# frozen_string_literal: true

module Admin
  module Queries
    class SessionsValidAfter
      include Deps[session_validity_repo: "repos.session_validity_repo"]

      def call = session_validity_repo.valid_after
    end
  end
end
