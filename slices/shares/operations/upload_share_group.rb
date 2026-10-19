# frozen_string_literal: true

module Shares
  module Operations
    class UploadShareGroup < Blog::Operation
      include Deps[
        "operations.add_share_group_files",
        client: "share_store.client",
        group_mutations: "repos.share_group_mutations",
      ]

      def call(uploads)
        step any(uploads)
        step available

        group = nil
        transaction { group = step add_share_group_files.call(create, uploads) }
      rescue StandardError
        client.discard(StoredKeys.of(group.share_group_files)) if group
        raise
      end

      private

      def any(uploads) = uploads.empty? ? Failure([:blank]) : Success(uploads)

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create
        Helpers::Code.retrying(group_mutations) { group_mutations.create }
      end
    end
  end
end
