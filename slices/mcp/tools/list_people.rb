# frozen_string_literal: true

module MCP
  module Tools
    class ListPeople < Base
      description "List everyone in the mention directory by name, each with its ID, key, name, Mastodon and " \
                  "Bluesky handles, created_at and updated_at. A post or social post mentions a person as @{key}"
      input_schema(API::Endpoints::ListPeople::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_people, input, server_context)
      end
    end
  end
end
