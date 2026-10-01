# frozen_string_literal: true

module Social
  module Queries
    class People
      include Deps[person_repo: "repos.person_repo"]

      def call = person_repo.all
    end
  end
end
