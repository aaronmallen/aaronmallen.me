# frozen_string_literal: true

module Projects
  module Queries
    class LinkableWorkEntries
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def matching(text, limit:) = work_entry_repo.linkable(:work_entries, text:, limit:)

      def named(ids) = work_entry_repo.linkable(:work_entries, ids:)
    end
  end
end
