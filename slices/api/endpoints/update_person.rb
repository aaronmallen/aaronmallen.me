# frozen_string_literal: true

module API
  module Endpoints
    class UpdatePerson < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: People::ID, **People::PROPERTIES },
        required: ["id"],
      }.freeze

      CONFLICTS = true
      REPLY = Serializers::Person.reference
      UNAVAILABLE = true

      include Deps[
        person_queries: "contacts.repos.person_queries",
        save_person: "contacts.operations.save_person",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def handle(id:, **fields)
        person = person_queries.by_id(id)
        return missing("person", id) if person.nil?

        saved(id, save_person.call(person.to_h.slice(*People::FIELDS).merge(fields), id:))
      end

      private

      def going_public(fields)
        stored = person_queries.by_id(fields[:id])&.key
        return if stored.nil?

        [stored, fields[:key]].compact.uniq.each do |key|
          id = social_post_queries.scheduled_mentioning(key)
          return format(People::MENTIONED, id, key) if id
        end
        nil
      end

      def saved(id, result)
        case result
          in Success(person) then Success(serialized(Serializers::Person, person))
          in Failure[:invalid, errors]
            invalid(Helpers::Wording.complaints(errors, People::COMPLAINTS, named: true))
          in Failure(:not_found) then missing("person", id)
          in Failure(:conflict) then Failure(Structs::Refusal.conflict(People::CONFLICT))
          in Failure[:google_failed, _] then Failure(Structs::Refusal.unavailable(People::GOOGLE_DOWN))
          in unmatched then unhandled(unmatched, People::UNSAVED)
        end
      end
    end
  end
end
