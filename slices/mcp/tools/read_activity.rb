# frozen_string_literal: true

module MCP
  module Tools
    class ReadActivity < Base
      MARKED = { "comment" => %w[name], "webmention" => %w[name excerpt] }.freeze

      description "Read one window of the activity feed, newest first, every kind in it: commits with their " \
                  "whole message, repository, sha and lines added and deleted, published posts, journal entries, " \
                  "posted social posts, approved webmentions, done tasks but never canceled ones, comments on " \
                  "tasks, closed work sessions, projects, sprints, suggestions, decision events and comments on " \
                  "decisions. A work session lands on the day it started, named for its task, with task_id and " \
                  "the seconds it ran as worked_seconds, whether or not the task is done. A comment's " \
                  "name is its text and its excerpt the title of its task or decision. A decision event's name " \
                  "is the decision's title, its status what happened, and its excerpt the reason, the edit " \
                  "note or else the option's title. " \
                  "Each row carries its kind, source_id, day, time, name and tags, and link, repo, sha, additions, " \
                  "deletions, status, targets, excerpt, task_id, decision_id and worked_seconds, null where its " \
                  "kind holds none. source_id is the ID of the row's own record, the one its kind's read tool " \
                  "takes: read_commit for a commit, read_post for a post, read_journal_entry for a journal entry, " \
                  "read_social_post for a social post, read_webmention for a webmention, read_task for a task and " \
                  "read_project for a project. A comment, session or decision event names its task or decision " \
                  "through task_id or decision_id. " \
                  "#{Blog::DayWindow::PAGING_NOTE}. A year runs to far more than one answer, so walk it a month at " \
                  "a time, newest first. A comment's name, and a webmention's name and excerpt, may come from " \
                  "someone else and come marked untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::ReadActivity::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input)
          hand_over(:read_activity, input, server_context) do |found|
            found.merge(activity: found.fetch(:activity).map { marked(it) })
          end
        end

        private

        def marked(row) = Untrusted.fields(row, *MARKED.fetch(row.fetch("kind"), Blog::Constants::EMPTY_ARRAY))
      end
    end
  end
end
