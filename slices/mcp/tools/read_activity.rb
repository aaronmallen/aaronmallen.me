# frozen_string_literal: true

module MCP
  module Tools
    class ReadActivity < Base
      CAP = 200
      FIELDS = %i[link repo sha additions deletions status targets excerpt task_id].freeze
      KINDS = Blog::Types::ActivityKind.values
      TIME_FORMAT = "%H:%M"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          kinds: {
            type: "array",
            items: { type: "string", enum: KINDS },
            description: "which kinds to read; every kind when you leave it out",
          },
          repos: {
            type: "array",
            items: { type: "string" },
            description: "repository names, with or without the owner; a name narrows commits and nothing else",
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "tag names on journal entries and tasks; a comment carries its task's tags",
          },
          text: { type: "string", description: "free text to match against the row" },
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "Read one window of the activity feed, newest first, every kind in it: commits with their " \
                  "whole message, repository, sha and lines added and deleted, published posts, journal entries, " \
                  "posted social posts, approved webmentions, done tasks but never canceled ones, comments on " \
                  "tasks, projects, sprints and suggestions. A comment's name is its text and its excerpt the " \
                  "task's title. " \
                  "Each row carries its kind, day, time and name, and whichever of link, repo, sha, additions, " \
                  "deletions, status, targets, excerpt and task_id its kind holds. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the window. " \
                  "One answer carries about #{CAP} rows, rounded out to the end of a day. Past that, partial " \
                  "comes back true and continue_to holds the day to send as to when you ask for the next " \
                  "window. A year runs to far more than one answer, so walk it a month at a time, newest first"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, **filters)
          first = Blog::TimeZone.parse_day(from)
          last = Blog::TimeZone.parse_day(to)
          return refuse("give from and to as days, such as 2026-01-01") unless first && last
          return refuse("from comes after to") if first > last

          window(first, last, filters, server_context)
        end

        private

        def answer_for(first, last, rows, partial:)
          payload = { from: first.iso8601, to: last.iso8601, count: rows.length, partial: }
          payload[:continue_to] = (rows.last.occurred_on - 1).iso8601 if partial

          answer(payload.merge(activity: rows.map { entry(it) }))
        end

        def entry(row)
          {
            kind: row.type,
            date: row.occurred_on.iso8601,
            time: row.occurred_at.strftime(TIME_FORMAT),
            name: row.name,
          }.merge(row.to_h.slice(*FIELDS).compact)
        end

        def found(first, last, filters, server_context, limit: nil)
          activity_between(server_context).call(
            from: first,
            to: last,
            types: kinds(filters[:kinds]),
            repos: Array(filters[:repos]),
            tags: Array(filters[:tags]),
            text: filters[:text],
            limit:,
          )
        end

        def kinds(chosen)
          asked = KINDS & Array(chosen).map(&:to_s)

          asked.empty? ? KINDS : asked
        end

        def older?(first, boundary, filters, server_context)
          boundary > first && found(first, boundary - 1, filters, server_context, limit: 1).any?
        end

        def window(first, last, filters, server_context)
          head = found(first, last, filters, server_context, limit: CAP + 1)
          return answer_for(first, last, head, partial: false) if head.length <= CAP

          boundary = head[CAP - 1].occurred_on
          rounded = head.take_while { it.occurred_on > boundary } + found(boundary, boundary, filters, server_context)

          answer_for(first, last, rounded, partial: older?(first, boundary, filters, server_context))
        end
      end
    end
  end
end
