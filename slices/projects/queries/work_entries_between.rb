# frozen_string_literal: true

module Projects
  module Queries
    class WorkEntriesBetween
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def call(from:, to:) = work_entry_repo.between(from.year, to.year)
    end
  end
end
