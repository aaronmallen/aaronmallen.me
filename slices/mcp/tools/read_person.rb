# frozen_string_literal: true

module MCP
  module Tools
    class ReadPerson < Base
      description "Read one person in the mention directory by ID, such as a person hit from search: its key, " \
                  "name, Mastodon and Bluesky handles, created_at and updated_at"
      input_schema(API::Endpoints::ReadPerson::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_person, input, server_context)
      end
    end
  end
end
