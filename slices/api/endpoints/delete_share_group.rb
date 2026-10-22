# frozen_string_literal: true

module API
  module Endpoints
    class DeleteShareGroup < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze
      UNAVAILABLE = true

      include Deps[delete_share_group: "shares.operations.delete_share_group"]

      def handle(id:)
        case delete_share_group.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then missing("share group", id)
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(Helpers::Upload::STORE_DOWN))
        end
      end
    end
  end
end
