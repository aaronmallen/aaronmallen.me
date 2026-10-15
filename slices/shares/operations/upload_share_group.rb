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

        transaction { step add_share_group_files.call(create, uploads) }
      end

      private

      def any(uploads) = uploads.empty? ? Failure([:blank]) : Success(uploads)

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create(attempts = Code::ATTEMPTS)
        group_mutations.create(code: Code.secret)
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless group_mutations.violated_constraint(e) == Code::KEY && attempts > 1

        create(attempts - 1)
      end
    end
  end
end
