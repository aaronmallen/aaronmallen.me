# frozen_string_literal: true

module MCP
  module Tools
    class DropSprint < Base
      description "Drop a sprint that has not started yet. Its tasks go back to next"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
