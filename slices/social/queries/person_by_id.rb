# frozen_string_literal: true

module Social
  module Queries
    class PersonById
      include Deps[person_repo: "repos.person_repo"]

      def call(id) = person_repo.by_id(id)
    end
  end
end
