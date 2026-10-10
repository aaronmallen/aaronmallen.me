# frozen_string_literal: true

module Record
  module Operations
    class ImportPullRequests < Blog::Operation
      include Record::Remote

      OVERLAP = 24 * 60 * 60

      include Deps[
        "github.client",
        pull_request_mutations: "repos.pull_request_mutations",
        pull_request_queries: "repos.pull_request_queries",
      ]

      def call(now: Time.now)
        found = step authored(now)

        pull_request_mutations.import(found)
        found.size
      end

      private

      def authored(now)
        remote(client) do
          updated_since = pull_request_queries.newest_import_at&.-(OVERLAP)
          Success(client.authored_pull_requests(updated_since:, now:))
        end
      end
    end
  end
end
