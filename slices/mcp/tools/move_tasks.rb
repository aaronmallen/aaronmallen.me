# frozen_string_literal: true

module MCP
  module Tools
    class MoveTasks < Base
      description "Move up to 100 tasks to next, someday, external or today's sprint. One that is missing moves " \
                  "none. Each note may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
