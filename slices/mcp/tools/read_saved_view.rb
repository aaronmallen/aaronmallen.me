# frozen_string_literal: true

module MCP
  module Tools
    class ReadSavedView < Base
      description "Read the records one saved view shows on its admin screen, with its saved filters set: tasks, " \
                  "blog posts, journal entries or activity rows. A filter the screen no longer reads falls back " \
                  "to its default. The answer carries the view, count and records. A tasks or posts view pages " \
                  "like list_tasks: when more remain, partial comes back true and next_page holds the number to " \
                  "send as page. A journal or activity view pages by day: partial comes back true and " \
                  "continue_to holds the day to send as continue_to. An activity row carries its kind, day, time " \
                  "and whole name, and whichever of link, repo, sha, additions, deletions, status, targets, " \
                  "excerpt, task_id, decision_id, worked_seconds and tags its kind holds, as read_activity does. " \
                  "Reading a Today, Next, Someday or External tasks view claims today's sprint, starting it when " \
                  "today has none yet and carrying in what the day before left open, as read_current_sprint and " \
                  "the admin's task list do"
      input_schema(API::Endpoints::ReadSavedView::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_saved_view, input, server_context)
      end
    end
  end
end
