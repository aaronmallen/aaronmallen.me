# frozen_string_literal: true

module Record
  module Repos
    class PullRequestMutations < Blog::DB::Repo
      include Dry::Monads[:result]

      IMPORT_LOCK = 303_306

      def import(found)
        importer = pull_requests.command(:import)

        transaction { found.each { importer.call(it) } }
      end

      def with_import_lock(&) = pull_requests.with_advisory_lock(IMPORT_LOCK, busy: Failure(:lock_busy), &)
    end
  end
end
