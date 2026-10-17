# frozen_string_literal: true

module Media
  module Operations
    class UploadPhoto < Blog::Operation
      include Deps[
        "operations.detect_photo_type",
        client: "media_store.client",
        contract: "contracts.photo_contract",
        photo_mutations: "repos.photo_mutations",
        processor: "operations.process_photo",
      ]

      def call(file)
        step available
        photo = step(validate(file)).fetch(:photo)
        type = detect_photo_type.call(photo)
        bytes = photo.read
        step measure(bytes, type)
        processed = step process(bytes, type)

        transaction { save(processed, type) }
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def discard(keys)
        keys.each do |key|
          client.delete(key)
        rescue ObjectStore::Client::Error
          next
        end
      end

      def key_for(type) = "#{ObjectStore::Key.generate}.#{type}"

      def measure(bytes, type)
        pixels = processor.pixels(bytes, type)
        return Failure([:unreadable]) unless pixels

        pixels > ProcessPhoto::MAX_PIXELS ? Failure([:oversized]) : Success(pixels)
      end

      def process(bytes, type)
        processed = processor.call(bytes, type)

        processed ? Success(processed) : Failure([:unreadable])
      end

      def save(processed, type)
        record = photo_mutations.create(
          key: key_for(type), width: processed.width, height: processed.height, byte_size: processed.body.bytesize,
          widths: processed.variants.keys,
        )
        objects = { record.key => processed.body, **processed.variants.transform_keys { record.variant_key(it) } }
        step store(objects, type)
        record
      end

      def store(objects, type)
        stored = []
        objects.each do |key, body|
          client.put(key, body, content_type: Blog::Types::PhotoType.mapping.fetch(type))
          stored << key
        end
        Success(stored)
      rescue ObjectStore::Client::Error
        discard(stored)
        Failure([:unavailable])
      end

      def validate(file) = validated(contract.call(photo: file))
    end
  end
end
