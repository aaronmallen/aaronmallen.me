# frozen_string_literal: true

module MCP
  module Tools
    class DeleteEvent < Base
      description "Delete one Google calendar event from Google for good. It cannot come back. For a recurring " \
                  "event, scope this deletes the one event and all the whole series. An event on a work calendar, " \
                  "or one Google lets the owner only read, refuses it"
      endpoint
    end
  end
end
