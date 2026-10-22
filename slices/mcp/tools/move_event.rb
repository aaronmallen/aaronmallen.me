# frozen_string_literal: true

module MCP
  module Tools
    class MoveEvent < Base
      description "Move one Google calendar event to another day, today or later, at the same times, as a drag on " \
                  "the admin's calendar does, and write the move to Google. For a recurring event, scope this moves " \
                  "the one event and all moves the whole series by as many days. An event on a work calendar, or " \
                  "one Google lets the owner only read, refuses it"
      endpoint
    end
  end
end
