# frozen_string_literal: true

require "securerandom"

module Media
  module Operations
    class UploadPhoto < Operation
      KEY_BYTES = 16

      include Deps[
        "store.client",
        contract: "contracts.photo_contract",
        photo_mutations: "repos.photo_mutations",
        processor: "operations.process_photo",
      ]

      def call(file)
        step available
        photo = step(validate(file)).fetch(:photo)
        type = PhotoType.detect(photo)
        bytes = photo.read
        step measure(bytes, type)
        processed = step process(bytes, type)

        transaction { save(processed, type) }
      end

      private

      def available = client.configured? ? Success(client) : Failure([:unavailable])

      def key_for(type) = "#{SecureRandom.hex(KEY_BYTES)}.#{type.extension}"

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
        )
        step store(record.key, processed.body, type)
        record
      end

      def store(key, body, type)
        client.put(key, body, content_type: type.content_type)
        Success(key)
      rescue Store::Client::Error
        Failure([:unavailable])
      end

      def validate(file) = validated(contract.call(photo: file))
    end
  end
end
