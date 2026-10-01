# frozen_string_literal: true

module MCP
  module Tools
    class ListSprints < Base
      description "List sprints by day, oldest first, each with how many tasks it carried in from the day " \
                  "before. Leave from and to both out for today's sprint and every one planned after it; " \
                  "leave one out to leave that end open. #{Paging::USAGE}"
      input_schema(API::Endpoints::ListSprints::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_sprints, input, server_context)
      end
    end
  end
end
