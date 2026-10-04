# frozen_string_literal: true

module MCP
  module Prompts
    class Report < Prompt
      USER = "user"
      WRAP = /(?<!\n)\n(?!\n)/

      RULES = <<~RULES
        The tools only hand back data, so the report is yours to write. Build it from what they return and
        nothing else, and say so when a part of the range holds nothing. Lead with what took the most time and
        effort, then the rest. Name the repositories, posts, projects and tasks you draw on, and keep dates as
        the tools give them.
      RULES

      prompt_name "report"
      title "Report on a date range"
      description "Walk the activity feed and the records beside it over a date range, then write a full report " \
                  "of the work done in it"
      arguments [
        Prompt::Argument.new(name: "from", description: "the first day of the range, as YYYY-MM-DD", required: true),
        Prompt::Argument.new(name: "to", description: "the last day of the range, as YYYY-MM-DD", required: true),
      ]

      class << self
        def template(args)
          first = Blog::TimeZone.parse_day(args[:from].to_s)
          last = Blog::TimeZone.parse_day(args[:to].to_s)
          refuse("give from and to as days, such as 2026-01-01") unless first && last
          refuse("from comes after to") if first > last
          refuse(Blog::DayWindow::TOO_LONG) if Blog::DayWindow.too_long?(first, last)

          Prompt::Result.new(description: headline(first, last), messages: [say(instructions(first, last))])
        end

        private

        def headline(first, last) = "Report on #{first.iso8601} to #{last.iso8601}"

        def instructions(first, last)
          ["#{headline(first, last)}.", steps(first.iso8601, last.iso8601), RULES].map { unwrap(it) }.join("\n\n")
        end

        def refuse(message)
          raise Server::RequestHandlerError.new(
            message,
            nil,
            error_type: :invalid_arguments,
            error_code: JsonRpcHandler::ErrorCode::INVALID_PARAMS,
          )
        end

        def say(text) = Prompt::Message.new(role: USER, content: Content::Text.new(text))

        def steps(from, to)
          <<~TEXT
            First call summarize_activity with from #{from} and to #{to}. It counts the range by kind, by month and
            by repository, so you see where the work sits before you read any of it.

            Then call read_activity with from #{from} and to #{to}. When partial comes back true, call it again with
            the same from and continue_to as to, and keep going until partial comes back false. For a long range,
            read it a month at a time, newest first, and page each month the same way.

            Last, fill in what the feed leaves out. Call list_tasks with the statuses open and in_progress for the
            work still waiting, list_projects for every project and where it stands, read_analytics with from
            #{from} and to #{to} for views and visitors, and list_messages with from #{from} and to #{to} for what
            people sent through the contact form.

            The feed counts only tasks marked done. Call list_tasks with the status canceled and from #{from} and to
            #{to} for the tasks dropped in the range, and report them apart from the done ones, since they are not
            work done.
          TEXT
        end

        def unwrap(text) = text.strip.gsub(WRAP, " ")
      end
    end
  end
end
