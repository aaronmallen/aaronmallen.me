# frozen_string_literal: true

module Shares
  module Operations
    class UploadShare < Blog::Operation
      UNKNOWN_TYPE = "application/octet-stream"

      include Deps[
        client: "share_store.client",
        contract: "contracts.upload_contract",
        share_mutations: "repos.share_mutations",
        share_queries: "repos.share_queries",
        short_code_queries: "repos.short_code_queries",
      ]

      def call(upload)
        step available
        fields = step validate(Hash(upload))

        transaction { save(fields) }
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create(fields)
        Helpers::Code.retrying(share_mutations) do
          share_mutations.create(
            code: short_code_queries.free_code, key: ObjectStore::Key.generate,
            filename: fields[:filename], content_type: fields[:content_type], byte_size: fields[:file].size,
          )
        end
      end

      def form(upload)
        type = Blog::Types::TrimmedText[upload[:type]]

        { file: upload[:tempfile], filename: upload[:filename], content_type: type.empty? ? UNKNOWN_TYPE : type }
      end

      def save(fields)
        share = share_queries.find(create(fields))
        step store(share, fields)
        share
      end

      def store(share, fields)
        fields[:file].rewind
        client.put(share.key, fields[:file], content_type: share.content_type)
        Success(share)
      rescue ObjectStore::Client::Error
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
