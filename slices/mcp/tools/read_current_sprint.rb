# frozen_string_literal: true

module MCP
  module Tools
    class ReadCurrentSprint < Base
      description "Read today's sprint and every task in it, in order. Opening it starts the sprint when " \
                  "today has none yet and carries in what the day before left open, as the admin does. " \
                  "#{Untrusted::TASKS}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
