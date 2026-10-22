# frozen_string_literal: true

module API
  module Endpoints
    class ListPeople < Endpoint
      STARRED = Blog::Types::ContactShow["starred"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: {
            type: "string",
            description: [
              "words to find in a name, nickname, key, company, job title, handle, email or phone;",
              "without the contacts scope only the name, key and handles",
            ].join(" "),
          },
          show: {
            type: "string",
            enum: Blog::Types::ContactShow.values,
            description: "mentionable keeps the people with a key; starred needs the contacts scope; all when left out",
          },
          label: { type: "string", description: "keeps the people holding this label; needs the contacts scope" },
        },
      }.freeze

      REPLY = Helpers::Schema.object({ people: Helpers::Schema.list(Serializers::Person.reference) }).freeze
      SCOPED = true

      include Deps[person_queries: "contacts.repos.person_queries"]

      def handle(scopes:, query: nil, show: nil, label: nil)
        open = !People.contacts?(scopes)
        return Failure(Structs::Refusal.unscoped(OperationTable::CONTACTS)) if open && (label || show == STARRED)

        people = person_queries.listed(query: Blog::Types::OptionalText[query], show:, label:, open:)
        Success(people: serialized(Serializers::Person, people).map { People.shown(it, scopes) })
      end
    end
  end
end
