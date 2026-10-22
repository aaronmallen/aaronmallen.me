# frozen_string_literal: true

module MCP
  module Tools
    class CreateEvent < Base
      description "Make an event on one of the owner's Google calendars, as the admin's calendar does, and write it " \
                  "to Google. Give starts and ends as HH:MM in #{Blog::TimeZone::NAME}, or all_day true for an event " \
                  "with no times. A calendar on a work account, or one Google lets the owner only read, refuses " \
                  "it. The event shows in list_calendar once the sync this queues copies it from Google"
      endpoint
    end
  end
end
