# frozen_string_literal: true

module MCP
  module Tools
    class SaveTag < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Helpers::Schema::ID.merge(
            description: "the tag to rename or recolour; leave it out to add a new one",
          ),
          **API::Endpoints::TagEndpoint::PROPERTIES,
        },
        required: ["scope"],
      }.freeze

      description "Add a tag to a scope, or rename or recolour one in it when you give its id. #{TAG_KINDS}. A new " \
                  "tag needs a name and takes the least used colour in its scope unless you give one. On a change, a " \
                  "field you leave out keeps what it has, and a rename follows the tag onto every record that " \
                  "carries it"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(server_context:, **input)
          hand_over(input.key?(:id) ? :update_tag : :create_tag, input, server_context)
        end
      end
    end
  end
end
