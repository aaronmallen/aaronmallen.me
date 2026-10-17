# frozen_string_literal: true

module API
  module Endpoints
    class UploadShareGroup < Endpoint
      UNAVAILABLE = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          files: {
            type: "array", items: Helpers::Upload::FILE, minItems: 1,
            description: "the files to share under one link",
          },
        },
        required: ["files"],
      }.freeze

      REPLY = Serializers::ShareGroup.reference

      include Deps[upload_share_group: "shares.operations.upload_share_group"]

      def handle(files:)
        uploads = files.map { read(it.transform_keys(&:to_sym)) }
        return invalid(files: [Helpers::Upload::NOT_BASE64]) unless uploads.all?

        case upload_share_group.call(uploads)
          in Success(group) then Success(serialized(Serializers::ShareGroup, group, settings:))
          in Failure[:invalid, errors] then refused(errors)
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(Helpers::Upload::STORE_DOWN))
        end
      end

      private

      def read(file) = Helpers::Upload.decoded(file.fetch(:data))&.then { Helpers::Upload.file(it, **file) }

      def refused(errors)
        complaints = { files: Helpers::Wording.complaints(errors, {}, named: true).values.flatten }

        Failure(Structs::Refusal.invalid(complaints, message: Helpers::Wording.summary(complaints)))
      end
    end
  end
end
