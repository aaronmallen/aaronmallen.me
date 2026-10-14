# frozen_string_literal: true

module API
  module Endpoints
    class UploadShare < Endpoint
      FIELDS = { file: :data }.freeze
      UNAVAILABLE = true

      SCHEMA = Helpers::Upload::FILE.except(:type).freeze
      REPLY = Serializers::Share.reference

      include Deps[upload_share: "shares.operations.upload_share"]

      def handle(data:, **fields)
        bytes = Helpers::Upload.decoded(data)
        return invalid(data: [Helpers::Upload::NOT_BASE64]) unless bytes

        case upload_share.call(Helpers::Upload.file(bytes, **fields))
          in Success(share) then Success(serialized(Serializers::Share, share, origin: share_origin))
          in Failure[:invalid, errors] then rejected(errors.transform_keys { FIELDS.fetch(it, it) }, {})
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(Helpers::Upload::STORE_DOWN))
        end
      end
    end
  end
end
