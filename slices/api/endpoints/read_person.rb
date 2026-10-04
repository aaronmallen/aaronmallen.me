# frozen_string_literal: true

module API
  module Endpoints
    class ReadPerson < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: People::ID }, required: ["id"] }.freeze
      REPLY = Serializers::Person.reference

      include Deps[person_by_id: "social.queries.person_by_id"]

      def handle(id:)
        person = person_by_id.call(id)

        person ? Success(serialized(Serializers::Person, person)) : not_found(People.missing(id))
      end
    end
  end
end
