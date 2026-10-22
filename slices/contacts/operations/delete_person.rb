# frozen_string_literal: true

module Contacts
  module Operations
    class DeletePerson < ContactOperation
      include Deps[person_mutations: "repos.person_mutations", person_queries: "repos.person_queries"]

      def call(id)
        person = step find(id)
        step(written { removed(person) })

        person_mutations.delete(person.id)
      end

      private

      def find(id)
        found(person_queries.by_id(id))
      end

      def removed(person)
        connection = connection(person) if person.google_id
        account(connection).delete(api_url("people/#{person.google_id}:deleteContact")) if connection
        Success(person)
      rescue Google::NotFound
        Success(person)
      end
    end
  end
end
