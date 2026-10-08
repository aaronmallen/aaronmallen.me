# frozen_string_literal: true

module MCP
  module Tools
    class PlanSprint < Base
      description "Plan the sprint for a day after today, so tasks can be scheduled into it before it starts"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
