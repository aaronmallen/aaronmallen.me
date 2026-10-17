# frozen_string_literal: true

module Media
  module Operations
    class UploadPhoto < Blog::Operation
      MEGAPIXEL = 1_000_000
      LIMITS = {
        size: Blog::Helpers::Figures.size(Contracts::PhotoContract::MAX_BYTES),
        megapixels: ProcessPhoto::MAX_PIXELS / MEGAPIXEL,
      }.freeze

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
        stored = step store(processed, type)

        save(processed, stored)
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def key_for(type) = "#{ObjectStore::Key.generate}.#{type}"

      def measure(bytes, type)
        pixels = processor.pixels(bytes, type)
        return Failure([:unreadable]) unless pixels

        pixels > ProcessPhoto::MAX_PIXELS ? Failure([:oversized]) : Success(pixels)
      end

      def objects(key, processed)
        { key => processed.body, **processed.variants.transform_keys { "#{it}/#{key}" } }
      end

      def process(bytes, type)
        processed = processor.call(bytes, type)

        processed ? Success(processed) : Failure([:unreadable])
      end

      def save(processed, stored)
        transaction do
          photo_mutations.create(
            key: stored.first, width: processed.width, height: processed.height, byte_size: processed.body.bytesize,
            widths: processed.variants.keys,
          )
        end
      rescue StandardError
        client.discard(stored)
        raise
      end

      def store(processed, type)
        stored = []
        objects(key_for(type), processed).each do |key, body|
          client.put(key, body, content_type: Blog::Types::PhotoType.mapping.fetch(type))
          stored << key
        end
        Success(stored)
      rescue ObjectStore::Client::Error
        client.discard(stored)
        Failure([:unavailable])
      end

      def validate(file) = validated(contract.call(photo: file))
    end
  end
end
