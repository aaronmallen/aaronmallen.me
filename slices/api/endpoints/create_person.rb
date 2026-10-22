# frozen_string_literal: true

module API
  module Endpoints
    class CreatePerson < Endpoint
      SCHEMA = { additionalProperties: false, properties: People::PROPERTIES, required: %w[name] }.freeze
      REPLY = Serializers::Person.reference
      SCOPED = true
      UNAVAILABLE = true

      include Deps[
        save_person: "contacts.operations.save_person",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def handle(scopes:, **fields)
        refusal = People.unscoped(fields, scopes)
        return Failure(refusal) if refusal

        case save_person.call(fields)
          in Success(person) then Success(People.shown(serialized(Serializers::Person, person), scopes))
          in Failure[:invalid, errors] then invalid(People.complaints(errors))
          in Failure[:google_failed, _] then Failure(Structs::Refusal.unavailable(People::GOOGLE_DOWN))
          in unmatched then unhandled(unmatched, People::UNSAVED)
        end
      end

      private

      def going_public(fields)
        return unless fields[:key]

        id = social_post_queries.scheduled_mentioning(fields[:key])
        format(People::MENTIONED, id, fields[:key]) if id
      end
    end
  end
end
