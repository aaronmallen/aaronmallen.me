# frozen_string_literal: true

module Contacts
  module Operations
    class SavePerson < Blog::Operation
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      CONSTRAINTS = {
        "people_key_check" => [:key, Blog::Contract::BLANK],
        "people_key_index" => [:key, "taken"],
        "people_name_check" => [:name, Blog::Contract::BLANK],
      }.freeze
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
        fields = step with_did(person, fields)

        step persist(person, fields)
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
        constrained(person_mutations, CONSTRAINTS) do
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

      def validate(params) = validated(contract.call(params.slice(*contract_keys)))

      def with_did(person, fields)
        return Success(fields) unless fields.key?(:bluesky_handle)

        resolve(person, fields[:bluesky_handle]).fmap { fields.merge(bluesky_did: it) }
      end
    end
  end
end
