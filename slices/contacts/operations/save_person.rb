# frozen_string_literal: true

module Contacts
  module Operations
    class SavePerson < ContactOperation
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      CONSTRAINTS = {
        "people_key_check" => [:key, Blog::Contract::BLANK],
        "people_key_index" => [:key, "taken"],
        "people_name_check" => [:name, Blog::Contract::BLANK],
      }.freeze
      PARTS = Helpers::GoogleBody::NAME_PARTS.keys.freeze
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
        connection = pushed_to(person, fields)

        step(written { connection ? pushed(person, fields, connection) : persist(person, fields) { it } })
      end

      private

      def conflict(person, held, account)
        person_mutations.update(person.id, **Helpers::GooglePerson.row(held, groups(account)))
        Failure(:conflict)
      end

      def contact(saved, person, fields)
        renamed = fields.key?(:name) && !fields.keys.intersect?(PARTS) && person&.name != fields[:name]

        renamed ? saved.to_h.merge(PARTS.to_h { [it, nil] }) : saved.to_h
      end

      def created(account, body)
        account.post(api_url("people:createContact", personFields: Helpers::GooglePerson::FIELDS), body)
      end

      def find(id)
        return Success(nil) unless id

        found(person_queries.by_id(id))
      end

      def held(account, person)
        return unless person&.google_id

        account.get(api_url("people/#{person.google_id}"), personFields: Helpers::GooglePerson::FIELDS)
      end

      def labelled(account, labels)
        by_name = groups(account).invert
        added = (labels - by_name.keys).to_h do |name|
          [name, account.post(api_url("contactGroups"), { contactGroup: { name: } }).fetch("resourceName")]
        end

        by_name.merge(added)
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
            yield(person ? person_mutations.update(person.id, **fields) : person_mutations.create(**fields))
          end)
        end
      end

      def pushed(person, fields, connection)
        account = account(connection)
        held = held(account, person)
        return conflict(person, held, account) if held && person.google_etag && held["etag"] != person.google_etag

        persist(person, fields) do |saved|
          found = sent(account, contact(saved, person, fields), held, touched(fields))
          person_mutations.update(saved.id, **found, google_connection_id: connection.id)
        end
      end

      def pushed_to(person, fields)
        connection(person) unless person&.google_id && touched(fields).empty?
      end

      def refused(code) = invalid(:bluesky_handle, code)

      def resolve(person, handle)
        return Success(nil) unless handle
        return Success(person.bluesky_did) if person&.bluesky_handle == handle

        lookup(handle)
      end

      def sent(account, contact, held, touched)
        groups = labelled(account, contact[:labels])
        body = Helpers::GoogleBody.body(contact, groups)
        found = held ? updated(account, held, body.slice(*touched)) : created(account, body)

        Helpers::GooglePerson.row(found, groups.invert)
      end

      def touched(fields) = Helpers::GoogleBody.touched(fields.keys)

      def updated(account, held, body)
        url = api_url(
          "#{held.fetch('resourceName')}:updateContact",
          updatePersonFields: body.keys.join(","), personFields: Helpers::GooglePerson::FIELDS,
        )

        account.patch(url, { etag: held["etag"], **body })
      end

      def validate(params) = validated(contract.call(params.slice(*contract_keys)))

      def with_did(person, fields)
        return Success(fields) unless fields.key?(:bluesky_handle)

        resolve(person, fields[:bluesky_handle]).fmap { fields.merge(bluesky_did: it) }
      end
    end
  end
end
