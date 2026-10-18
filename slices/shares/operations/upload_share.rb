# frozen_string_literal: true

module Shares
  module Operations
    class UploadShare < Blog::Operation
      UNKNOWN_TYPE = "application/octet-stream"

      include Deps[
        "operations.store_preview",
        client: "share_store.client",
        contract: "contracts.upload_contract",
        share_mutations: "repos.share_mutations",
        share_queries: "repos.share_queries",
        short_code_queries: "repos.short_code_queries",
      ]

      def call(upload)
        step available
        fields = step validate(Hash(upload))
        key = step store(fields)

        save(key, store_preview.call(fields[:file]), fields)
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create(key, preview_key, fields)
        Helpers::Code.retrying(share_mutations) do
          share_mutations.create(
            code: short_code_queries.free_code, key:, preview_key:,
            filename: fields[:filename], content_type: fields[:content_type], byte_size: fields[:file].size,
          )
        end
      end

      def form(upload)
        type = Blog::Types::TrimmedText[upload[:type]]

        { file: upload[:tempfile], filename: upload[:filename], content_type: type.empty? ? UNKNOWN_TYPE : type }
      end

      def save(key, preview_key, fields)
        transaction { share_queries.find(create(key, preview_key, fields)) }
      rescue StandardError
        client.discard([key, preview_key].compact)
        raise
      end

      def store(fields)
        key = ObjectStore::Key.generate
        fields[:file].rewind
        Success(client.put(key, fields[:file], content_type: fields[:content_type]))
      rescue ObjectStore::Client::Error
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
