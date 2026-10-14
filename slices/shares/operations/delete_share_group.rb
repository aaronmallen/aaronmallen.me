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
        transaction do
          group_mutations.delete(group.short_code_id)
          group.share_group_files.each { client.delete(it.key) }
        end
        Success(group)
      rescue ObjectStore::Client::Error
        Failure([:unavailable])
      end
    end
  end
end
