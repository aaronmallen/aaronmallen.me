# frozen_string_literal: true

require "securerandom"

module Shares
  module Operations
    class UploadShare < Blog::Operation
      KEY_BYTES = 16
      UNKNOWN_TYPE = "application/octet-stream"

      include Deps[
        client: "share_store.client",
        contract: "contracts.upload_contract",
        share_mutations: "repos.share_mutations",
        share_queries: "repos.share_queries",
      ]

      def call(upload)
        step available
        fields = step validate(Hash(upload))

        transaction { save(fields) }
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def create(fields, attempts = Code::ATTEMPTS)
        share_mutations.create(
          code: Code.random, key: SecureRandom.hex(KEY_BYTES),
          filename: fields[:filename], content_type: fields[:content_type], byte_size: fields[:file].size,
        )
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless share_mutations.violated_constraint(e) == Code::KEY && attempts > 1

        create(fields, attempts - 1)
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
      rescue Store::Client::Error
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
