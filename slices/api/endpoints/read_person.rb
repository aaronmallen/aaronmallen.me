# frozen_string_literal: true

module API
  module Endpoints
    class ReadPerson < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::Person.reference

      include Deps[person_queries: "social.repos.person_queries"]

      def handle(id:)
        person = person_queries.by_id(id)

        person ? Success(serialized(Serializers::Person, person)) : not_found(Helpers::Wording.missing("person", id))
      end
    end
  end
end
