# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTag < Base
      description "Remove one tag for good from its scope. #{TAG_KINDS}. Every record that carries the tag loses it. " \
                  "A tag that is the only tag on a task rule with no projects stays until the rule takes another tag " \
                  "or a project, or goes"
      endpoint
    end
  end
end
