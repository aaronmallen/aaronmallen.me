# frozen_string_literal: true

module API
  module Endpoints
    class DeleteShare < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze
      UNAVAILABLE = true

      include Deps[delete_share: "shares.operations.delete_share"]

      def handle(id:)
        case delete_share.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then missing("share", id)
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(Helpers::Upload::STORE_DOWN))
        end
      end
    end
  end
end
