# frozen_string_literal: true

module Activity
  module Queries
    class ContributorChoices
      include Deps[activity_repo: "repos.activity_repo"]

      def call = { agents: activity_repo.contributor_names(:agent), models: activity_repo.contributor_names(:model) }
    end
  end
end
