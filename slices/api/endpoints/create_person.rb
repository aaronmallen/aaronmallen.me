# frozen_string_literal: true

module API
  module Endpoints
    class CreatePerson < Endpoint
      SCHEMA = { additionalProperties: false, properties: People::PROPERTIES, required: %w[name key] }.freeze
      REPLY = Serializers::Person.reference

      include Deps[save_person: "social.operations.save_person"]

      def handle(**fields)
        case save_person.call(People::FIELDS.to_h { [it, fields[it]] })
        in Success(person) then Success(serialized(Serializers::Person, person))
        in Failure[:invalid, errors] then invalid(Wording.complaints(errors, People::COMPLAINTS, named: true))
        else failed(People::UNSAVED)
        end
      end
    end
  end
end
