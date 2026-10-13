# frozen_string_literal: true

module MCP
  module Tools
    class StageTask < Base
      description "Put one open task in backlog or ready, the stage that tells open tasks apart on a project board. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
