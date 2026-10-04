# frozen_string_literal: true

module API
  module Endpoints
    class ListPeople < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Schema.object({ people: Schema.list(Serializers::Person.reference) }).freeze

      include Deps[people: "social.queries.people"]

      def handle = Success(people: serialized(Serializers::Person, people.call))
    end
  end
end
