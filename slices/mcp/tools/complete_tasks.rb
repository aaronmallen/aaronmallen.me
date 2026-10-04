# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTasks < Base
      description "Mark up to 100 open or started tasks done at once, stamped with the time now. One that is " \
                  "missing or already closed completes none. " \
                  "Each note may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
