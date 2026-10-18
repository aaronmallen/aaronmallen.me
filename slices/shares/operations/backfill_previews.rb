# frozen_string_literal: true

require "stringio"

module Shares
  module Operations
    class BackfillPreviews
      include Deps[
        "operations.store_preview",
        client: "share_store.client",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call = group_queries.missing_previews.count { backfill(it) }

      private

      def backfill(file)
        stored = client.get(file.key)
        preview_key = stored && store_preview.call(StringIO.new(stored.body))
        return false unless preview_key

        group_mutations.update_file(file.id, preview_key:)
        true
      rescue ObjectStore::Client::Error
        false
      end
    end
  end
end
