# frozen_string_literal: true

module MCP
  module Tools
    class PlanSprint < Base
      description "Plan the sprint for a day after today, so tasks can be scheduled into it before it starts"
      input_schema(API::Endpoints::PlanSprint::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:plan_sprint, input, server_context)
      end
    end
  end
end
