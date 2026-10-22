# frozen_string_literal: true

module MCP
  module Tools
    class EditEvent < Base
      description "Edit one Google calendar event, as the admin's calendar does, and write the change to Google. A " \
                  "field you leave out keeps what it has. For a recurring event, scope this changes the one event " \
                  "and all changes the whole series, moving every event in it as far as this one moves. An event " \
                  "on a work calendar, or one Google lets the owner only read, refuses it. list_calendar shows the " \
                  "change once the sync this queues copies it from Google"
      endpoint
    end
  end
end
