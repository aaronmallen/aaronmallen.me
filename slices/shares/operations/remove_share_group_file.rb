# frozen_string_literal: true

module Shares
  module Operations
    class RemoveShareGroupFile < Blog::Operation
      include Deps[
        client: "share_store.client",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id, file_id)
        group = step found(group_queries.find(id))
        file = step found(group.share_group_files.find { it.id == file_id })
        step available

        step remove(group, file)
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def remove(group, file)
        transaction do
          group_mutations.remove_file(file.id)
          group_mutations.delete(group.short_code_id) if group.share_group_files.one?
          client.delete(file.key)
        end
        Success(group_queries.find(group.id))
      rescue ObjectStore::Client::Error
        Failure([:unavailable])
      end
    end
  end
end
