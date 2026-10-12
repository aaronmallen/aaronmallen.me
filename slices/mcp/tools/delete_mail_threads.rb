# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMailThreads < Base
      description "Delete up to #{Blog::Contract::MAX_IDS} mail threads at once, every message in each. One that is " \
                  "missing deletes none. No undo. Each deleted thread's subject comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
