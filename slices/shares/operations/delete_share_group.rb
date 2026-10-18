# frozen_string_literal: true

module Shares
  module Operations
    class DeleteShareGroup < Blog::Operation
      include Deps[
        client: "share_store.client",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id)
        group = step found(group_queries.find(id))
        step available

        step delete(group)
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def delete(group)
        group_mutations.delete(group.short_code_id)
        StoredKeys.of(group.share_group_files).each { delete_object(it) }
        Success(group)
      end

      def delete_object(key)
        client.delete(key)
      rescue ObjectStore::Client::Error
        nil
      end
    end
  end
end
