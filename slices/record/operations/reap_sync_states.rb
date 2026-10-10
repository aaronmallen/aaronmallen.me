# frozen_string_literal: true

module Record
  module Operations
    class ReapSyncStates < Blog::Operation
      include Record::Remote

      SYNCS = [Blog::Types::SyncName["commits"]].freeze

      include Deps[
        "github.client",
        commit_mutations: "repos.commit_mutations",
        sync_state_mutations: "repos.sync_state_mutations",
      ]

      def call
        keep = step repositories

        commit_mutations.reap_walks(keep:) + SYNCS.sum { sync_state_mutations.reap_failures(it, keep:) }
      end

      private

      def repositories
        remote(client) do
          listing = client.repository_names
          next Failure(:page_limit) if listing.cut_short?

          listing.items.empty? ? Failure(:no_repositories) : Success(listing.items)
        end
      end
    end
  end
end
