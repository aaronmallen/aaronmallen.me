# frozen_string_literal: true

module API
  module Endpoints
    class UpdatePerson < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: People::ID, **People::PROPERTIES },
        required: ["id"],
      }.freeze

      REPLY = Serializers::Person.reference

      include Deps[person_queries: "social.repos.person_queries", save_person: "social.operations.save_person"]

      def handle(id:, **fields)
        person = person_queries.by_id(id)
        return not_found(Helpers::Wording.missing("person", id)) if person.nil?

        saved(id, save_person.call(person.to_h.slice(*People::FIELDS).merge(fields), id:))
      end

      private

      def saved(id, result)
        case result
          in Success(person) then Success(serialized(Serializers::Person, person))
          in Failure[:invalid, errors]
            invalid(Helpers::Wording.complaints(errors, People::COMPLAINTS, named: true))
          in Failure(:not_found) then not_found(Helpers::Wording.missing("person", id))
          else failed(People::UNSAVED)
        end
      end
    end
  end
end
