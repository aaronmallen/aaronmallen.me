# frozen_string_literal: true

module MCP
  module Tools
    class ReadTask < Base
      COMMENTS = API::Serializers::TaskTimelineComment::KINDS

      description "Read one task: its title, note, status, list or sprint day, tags, links to other tasks both " \
                  "ways, the issue it syncs from (null for a local task), its created, updated and completed " \
                  "times, its comments, oldest first, the other records linked to it, grouped by kind, and its " \
                  "timeline: comments, work sessions with their IDs, moves, tag changes and status changes, " \
                  "oldest first. The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::ReadTask::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_task, input, server_context) { marked(it) }

        private

        def marked(task)
          task.merge(
            "note" => Untrusted.call(task.fetch("note")),
            comments: task.fetch(:comments).map { marked_body(it) },
            timeline: task.fetch(:timeline).map { COMMENTS.include?(it.fetch("kind")) ? marked_body(it) : it },
          )
        end

        def marked_body(entry) = entry.merge("body" => Untrusted.call(entry.fetch("body")))
      end
    end
  end
end
