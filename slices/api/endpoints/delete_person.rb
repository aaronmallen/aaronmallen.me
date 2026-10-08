# frozen_string_literal: true

module API
  module Endpoints
    class DeletePerson < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_person: "social.operations.delete_person"]

      def handle(id:)
        case delete_person.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("person", id))
          else failed("could not delete the person")
        end
      end
    end
  end
end
