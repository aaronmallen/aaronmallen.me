# frozen_string_literal: true

module MCP
  module Tools
    class ReadActivity < Base
      FIELDS = %i[link repo sha additions deletions status targets excerpt task_id decision_id worked_seconds
                  tags].freeze
      KINDS = Blog::Types::ActivityKind.values
      MARKED = { "comment" => %i[name], "webmention" => %i[name excerpt] }.freeze
      TIME_FORMAT = "%H:%M"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::WINDOW,
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
            description: "tags on journal entries, tasks and decisions; a comment or session takes its owner's tags",
          },
          text: { type: "string", description: "free text to match against the row" },
        },
        required: %w[from to],
      }.freeze

      description "Read one window of the activity feed, newest first, every kind in it: commits with their " \
                  "whole message, repository, sha and lines added and deleted, published posts, journal entries, " \
                  "posted social posts, approved webmentions, done tasks but never canceled ones, comments on " \
                  "tasks, closed work sessions, projects, sprints, suggestions, decision events and comments on " \
                  "decisions. A work session lands on the day it started, named for its task, with task_id and " \
                  "the seconds it ran as worked_seconds, whether or not the task is done. A comment's " \
                  "name is its text and its excerpt the title of its task or decision. A decision event's name " \
                  "is the decision's title, its status what happened, and its excerpt the reason, the edit " \
                  "note or else the option's title. " \
                  "Each row carries its kind, day, time and name, and whichever of link, repo, sha, additions, " \
                  "deletions, status, targets, excerpt, task_id, decision_id, worked_seconds and tags its kind " \
                  "holds. " \
                  "#{Blog::DayWindow::PAGING_NOTE}. A year runs to far more than one answer, so walk it a month at " \
                  "a time, newest first. A comment's name, and a webmention's name and excerpt, may come from " \
                  "someone else and come marked untrusted. #{Untrusted::WARNING}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, **filters)
          case Blog::DayWindow.days(from, to)
          in Success[first, last] then window(first, last, filters, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def entry(row)
          shown = {
            kind: row.type,
            date: row.occurred_on.iso8601,
            time: row.occurred_at.strftime(TIME_FORMAT),
            name: row.name,
          }.merge(row.to_h.slice(*FIELDS).compact)

          Untrusted.fields(shown, *MARKED.fetch(row.type, Blog::Constants::EMPTY_ARRAY))
        end

        def found(first, last, filters, server_context, limit:)
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

        def window(first, last, filters, server_context)
          page = Blog::DayWindow.page(first, last, day: :occurred_on.to_proc) do |from, to, limit|
            found(from, to, filters, server_context, limit:)
          end
          rows = page.fetch(:rows)
          payload = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

          answer(payload.merge(activity: rows.map { entry(it) }))
        end
      end
    end
  end
end
