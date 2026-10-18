# frozen_string_literal: true

module Shares
  module Operations
    class DeleteShare < Blog::Operation
      include Deps[
        client: "share_store.client", share_mutations: "repos.share_mutations", share_queries: "repos.share_queries",
      ]

      def call(id)
        share = step found(share_queries.find(id))
        step available

        step delete(share)
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def delete(share)
        transaction do
          share_mutations.delete(share.short_code_id)
          StoredKeys.of(share).each { client.delete(it) }
        end
        Success(share)
      rescue ObjectStore::Client::Error
        Failure([:unavailable])
      end
    end
  end
end
