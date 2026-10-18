# frozen_string_literal: true

module Shares
  module Operations
    class AddShareGroupFiles < Blog::Operation
      include Deps[
        "operations.store_preview",
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

      def keys(stored) = stored.flat_map { |key, fields| [key, fields[:preview_key]] }.compact

      def put(fields)
        key = ObjectStore::Key.generate
        fields[:file].rewind
        client.put(key, fields[:file], content_type: fields[:content_type])
      end

      def save(id, stored)
        transaction do
          stored.each do |key, fields|
            fields => { file:, **columns }
            group_mutations.add_file(id, key:, byte_size: file.size, **columns)
          end
          group_queries.find(id)
        end
      rescue StandardError
        client.discard(keys(stored))
        raise
      end

      def store(files)
        stored = {}
        files.each { stored[put(it)] = it.merge(preview_key: store_preview.call(it[:file])) }
        Success(stored)
      rescue ObjectStore::Client::Error
        client.discard(keys(stored))
        Failure([:unavailable])
      end

      def validate(upload) = validated(contract.call(form(upload)))
    end
  end
end
