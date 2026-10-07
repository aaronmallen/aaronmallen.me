# frozen_string_literal: true

module Social
  module Operations
    class SavePerson < Operation
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      FIELDS = %i[bluesky_handle key mastodon_handle name].freeze
      TAKEN = "taken"
      UNREACHABLE = "unreachable"
      UNRESOLVED = "unresolved"

      include Deps[contract: "contracts.person_contract", networks: "networks.all", person_repo: "repos.person_repo"]

      def call(params, id: nil)
        person = step find(id)
        fields = step validate(params)
        bluesky_did = step resolve(person, fields[:bluesky_handle])

        step persist(person, fields.merge(bluesky_did:))
      end

      private

      def find(id)
        return Success(nil) unless id

        found(person_repo.by_id(id))
      end

      def lookup(handle)
        did = networks.fetch(BLUESKY).resolve(handle)

        did ? Success(did) : refused(UNRESOLVED)
      rescue Social::Error
        refused(UNREACHABLE)
      end

      def persist(person, fields)
        Success(transaction { person ? person_repo.update(person.id, **fields) : person_repo.create(**fields) })
      rescue ROM::SQL::UniqueConstraintError
        Failure([:invalid, { key: [TAKEN] }])
      end

      def refused(code) = Failure([:invalid, { bluesky_handle: [code] }])

      def resolve(person, handle)
        return Success(nil) unless handle
        return Success(person.bluesky_did) if person&.bluesky_handle == handle

        lookup(handle)
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
