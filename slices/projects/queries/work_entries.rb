# frozen_string_literal: true

module Projects
  module Queries
    class WorkEntries
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def call = work_entry_repo.all
    end
  end
end
