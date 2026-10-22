# frozen_string_literal: true

module API
  module Endpoints
    class ReadPerson < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::Person.reference
      SCOPED = true

      include Deps[person_queries: "contacts.repos.person_queries"]

      def handle(id:, scopes:)
        person = person_queries.by_id(id)

        person ? Success(People.shown(serialized(Serializers::Person, person), scopes)) : missing("person", id)
      end
    end
  end
end
