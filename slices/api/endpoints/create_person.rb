# frozen_string_literal: true

module API
  module Endpoints
    class CreatePerson < Endpoint
      SCHEMA = { additionalProperties: false, properties: People::PROPERTIES, required: %w[name] }.freeze
      REPLY = Serializers::Person.reference

      include Deps[
        save_person: "contacts.operations.save_person",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def handle(**fields)
        case save_person.call(People::FIELDS.to_h { [it, fields[it]] })
          in Success(person) then Success(serialized(Serializers::Person, person))
          in Failure[:invalid, errors]
            invalid(Helpers::Wording.complaints(errors, People::COMPLAINTS, named: true))
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
