# frozen_string_literal: true

module API
  module Endpoints
    class ListPeople < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Schema.object({ people: Schema.list(Serializers::Person.reference) }).freeze

      include Deps[person_queries: "social.repos.person_queries"]

      def handle = Success(people: serialized(Serializers::Person, person_queries.all))
    end
  end
end
