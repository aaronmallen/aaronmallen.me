# frozen_string_literal: true

require "securerandom"

module Shares
  module Operations
    class AddShareGroupFiles < Blog::Operation
      include Deps[
        client: "share_store.client",
        contract: "contracts.upload_contract",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id, uploads)
        group = step found(group_queries.find(id))
        step any(uploads)
        step available
        files = uploads.map { step validate(Hash(it)) }

        transaction { save(group.id, files) }
      end

      private

      def any(uploads) = uploads.empty? ? Failure([:blank]) : Success(uploads)

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def discard(keys)
        keys.each do |key|
          client.delete(key)
        rescue ObjectStore::Client::Error
          next
        end
      end

      def form(upload)
        type = Blog::Types::TrimmedText[upload[:type]]

        {
          file: upload[:tempfile], filename: upload[:filename],
          content_type: type.empty? ? UploadShare::UNKNOWN_TYPE : type,
        }
      end

      def save(id, files)
        stored = []
        files.each do |fields|
          key = SecureRandom.hex(UploadShare::KEY_BYTES)
          group_mutations.add_file(
            id, key:, filename: fields[:filename], content_type: fields[:content_type], byte_size: fields[:file].size,
          )
          step store(key, fields, stored)
        end
        group_queries.find(id)
      end

      def store(key, fields, stored)
        fields[:file].rewind
        client.put(key, fields[:file], content_type: fields[:content_type])
        Success(stored << key)
      rescue ObjectStore::Client::Error
        discard(stored)
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
