# frozen_string_literal: true

module API
  module Endpoints
    class DeletePerson < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze
      UNAVAILABLE = true

      include Deps[delete_person: "contacts.operations.delete_person"]

      def handle(id:)
        case delete_person.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then missing("person", id)
          in Failure[:google_failed, _] then Failure(Structs::Refusal.unavailable(People::GOOGLE_DOWN))
          in unmatched then unhandled(unmatched, "could not delete the person")
        end
      end
    end
  end
end
