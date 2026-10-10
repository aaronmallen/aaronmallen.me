# frozen_string_literal: true

module Social
  module Operations
    class SavePerson < Blog::Operation
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      KEY_INDEX = "people_key_index"
      TAKEN = "taken"
      UNREACHABLE = "unreachable"
      UNRESOLVED = "unresolved"

      include Deps[
        contract: "contracts.person_contract",
        networks: "networks.all",
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
      rescue Social::Error
        refused(UNREACHABLE)
      end

      def persist(person, fields)
        Success(transaction do
          person ? person_mutations.update(person.id, **fields) : person_mutations.create(**fields)
        end)
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless person_mutations.violated_constraint(e) == KEY_INDEX

        Failure([:invalid, { key: [TAKEN] }])
      end

      def refused(code) = Failure([:invalid, { bluesky_handle: [code] }])

      def resolve(person, handle)
        return Success(nil) unless handle
        return Success(person.bluesky_did) if person&.bluesky_handle == handle

        lookup(handle)
      end

      def validate(params) = validated(contract.call(every_field(params)))
    end
  end
end
