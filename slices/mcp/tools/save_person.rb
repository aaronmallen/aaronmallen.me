# frozen_string_literal: true

module MCP
  module Tools
    class SavePerson < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Helpers::Schema::ID.merge(description: "the person to edit; leave it out to add a new one"),
          **API::Endpoints::People::PROPERTIES,
        },
      }.freeze

      description "Add a person to the mention directory, or edit one when you give its id, so a social post can " \
                  "mention them as @{key}. A new person needs a name, a key and at least one handle. A Bluesky " \
                  "handle is looked up on Bluesky as it saves, and one Bluesky does not know is refused. On an " \
                  "edit, a field you leave out keeps what it has, and null clears a handle. Use search_accounts " \
                  "to find a handle"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(server_context:, **input)
          hand_over(input.key?(:id) ? :update_person : :create_person, input, server_context)
        end
      end
    end
  end
end
