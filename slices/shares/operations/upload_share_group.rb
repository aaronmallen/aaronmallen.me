# frozen_string_literal: true

module Shares
  module Operations
    class UploadShareGroup < Blog::Operation
      include Deps[
        "operations.add_share_group_files",
        client: "share_store.client",
        group_mutations: "repos.share_group_mutations",
        short_code_queries: "repos.short_code_queries",
      ]

      def call(uploads)
        step any(uploads)
        step available

        transaction { step add_share_group_files.call(create, uploads) }
      end

      private

      def any(uploads) = uploads.empty? ? Failure([:blank]) : Success(uploads)

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create
        Helpers::Code.retrying(group_mutations) { group_mutations.create(code: short_code_queries.free_code) }
      end
    end
  end
end
