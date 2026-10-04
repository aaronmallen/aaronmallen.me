# frozen_string_literal: true

module Projects
  module Queries
    class WorkEntryById
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def call(id) = work_entry_repo.by_id(id)
    end
  end
end
