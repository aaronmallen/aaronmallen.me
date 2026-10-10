# frozen_string_literal: true

module Record
  module Repos
    class PullRequestMutations < Blog::DB::Repo
      IMPORT_LOCK = "pull request import"

      def import(found)
        importer = pull_requests.command(:import)

        transaction { found.each { importer.call(it) } }
      end

      def with_import_lock(&) = pull_requests.with_advisory_lock(IMPORT_LOCK, &)
    end
  end
end
