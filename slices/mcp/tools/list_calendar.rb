# frozen_string_literal: true

module MCP
  module Tools
    class ListCalendar < Base
      description "List each day in a range the way the admin's calendar shows it, oldest first, empty days " \
                  "included: the sprint planned for the day with its task count, the scheduled and published " \
                  "posts, the scheduled and sent social posts, and whether the journal holds an entry. A post " \
                  "or social post falls on the #{Blog::TimeZone::NAME} day it goes out; drafts stay out. " \
                  "Give from and to as YYYY-MM-DD; both days count, and the range runs at most " \
                  "#{Blog::DayWindow::LONGEST} days. To move something, use schedule_task, update_post or " \
                  "send_social_post"
      input_schema(API::Endpoints::ListCalendar::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_calendar, input, server_context)
      end
    end
  end
end
