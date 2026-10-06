# frozen_string_literal: true

module MCP
  module Tools
    class ReadActivity < Base
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
                  "deletions, status, targets, excerpt, task_id, decision_id, worked_seconds, views and " \
                  "contributors, null where its kind holds none. A task's contributors list who did the work, " \
                  "the owner when it lists none. contributor, agent and model keep only the tasks that match " \
                  "and drop every other kind. A post's views count the last 90 days, as the admin's activity screen " \
                  "does. source_id is the ID of the row's own record, the one its kind's read tool " \
                  "takes: read_commit for a commit, read_post for a post, read_journal_entry for a journal entry, " \
                  "read_social_post for a social post, read_webmention for a webmention, read_task for a task and " \
                  "read_project for a project. A comment, session or decision event names its task or decision " \
                  "through task_id or decision_id. " \
                  "#{Blog::DayWindow::PAGING_NOTE}. A year runs to far more than one answer, so walk it a month at " \
                  "a time, newest first. A comment's name, its excerpt when its task syncs from an issue, the name " \
                  "of a task or session when its task syncs from an issue, and a webmention's name and excerpt " \
                  "may come from someone else and come marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ

      class << self
        private

        def answered(found) = found.merge(activity: found.fetch(:activity).map { Untrusted.activity(it) })
      end
    end
  end
end
