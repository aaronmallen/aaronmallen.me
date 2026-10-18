# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMailThreads < Base
      description "Move up to #{Blog::Contract::MAX_IDS} mail threads to the trash at once, Gmail's Trash for a " \
                  "Gmail thread, so the owner can restore them. One that is missing moves none. Each trashed " \
                  "thread's subject comes marked untrusted. #{Untrusted::WARNING}"
      endpoint
    end
  end
end
