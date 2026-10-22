# frozen_string_literal: true

module Contacts
  module Operations
    class SavePerson < Blog::Operation
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      KEY_INDEX = "people_key_index"
      TAKEN = "taken"
      UNREACHABLE = "unreachable"
      UNRESOLVED = "unresolved"

      include Deps[
        contract: "contracts.person_contract",
        networks: "social_networks.all",
        person_mutations: "repos.person_mutations",
        person_queries: "repos.person_queries",
      ]

      def call(params, id: nil)
        person = step find(id)
        fields = step validate(params)
        bluesky_did = step resolve(person, fields[:bluesky_handle])

        step persist(person, fields.merge(bluesky_did:))
      end

      private

      def find(id)
        return Success(nil) unless id

        found(person_queries.by_id(id))
      end

      def lookup(handle)
        did = networks.fetch(BLUESKY).resolve(handle)

        did ? Success(did) : refused(UNRESOLVED)
      rescue Blog::ServiceError
        refused(UNREACHABLE)
      end

      def persist(person, fields)
        constrained(person_mutations, KEY_INDEX => [:key, TAKEN]) do
          Success(transaction do
            person ? person_mutations.update(person.id, **fields) : person_mutations.create(**fields)
          end)
        end
      end

      def refused(code) = invalid(:bluesky_handle, code)

      def resolve(person, handle)
        return Success(nil) unless handle
        return Success(person.bluesky_did) if person&.bluesky_handle == handle

        lookup(handle)
      end
    end
  end
end
