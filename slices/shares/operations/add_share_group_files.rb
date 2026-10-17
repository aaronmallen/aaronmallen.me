# frozen_string_literal: true

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
        stored = step store(files)

        save(group.id, stored)
      end

      private

      def any(uploads) = uploads.empty? ? Failure([:blank]) : Success(uploads)

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def form(upload)
        type = Blog::Types::TrimmedText[upload[:type]]

        {
          file: upload[:tempfile], filename: upload[:filename],
          content_type: type.empty? ? UploadShare::UNKNOWN_TYPE : type,
        }
      end

      def put(fields)
        key = ObjectStore::Key.generate
        fields[:file].rewind
        client.put(key, fields[:file], content_type: fields[:content_type])
      end

      def save(id, stored)
        transaction do
          stored.each do |key, fields|
            group_mutations.add_file(
              id, key:, filename: fields[:filename], content_type: fields[:content_type], byte_size: fields[:file].size,
            )
          end
          group_queries.find(id)
        end
      rescue StandardError
        client.discard(stored.keys)
        raise
      end

      def store(files)
        stored = {}
        files.each { stored[put(it)] = it }
        Success(stored)
      rescue ObjectStore::Client::Error
        client.discard(stored.keys)
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
