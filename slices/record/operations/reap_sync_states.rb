# frozen_string_literal: true

module Record
  module Operations
    class ReapSyncStates < Operation
      SYNCS = [Blog::Types::SyncName["commits"]].freeze

      include Deps[
        "github.client",
        commit_repo: "repos.commit_repo",
        sync_state_repo: "repos.sync_state_repo",
      ]

      def call
        keep = step repositories

        commit_repo.reap_walks(keep:) + SYNCS.sum { sync_state_repo.reap_failures(it, keep:) }
      end

      private

      def repositories
        return Failure(:not_configured) unless client.configured?

        listing = client.repository_names
        return Failure(:page_limit) if listing.cut_short?

        listing.items.empty? ? Failure(:no_repositories) : Success(listing.items)
      rescue Record::GitHub::Client::RateLimited
        Failure(:rate_limited)
      rescue Record::GitHub::Client::Error
        Failure(:github_failed)
      end
    end
  end
end
