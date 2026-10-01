# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class TaskTool < Base
      BAD_DAY = "give from and to as days, such as 2026-01-01"
      BAD_WINDOW = "from comes after to"
      CONTROL = "holds a control character"
      LOCAL = "local"
      NO_TASK = "no task has the ID %s"
      UNSAVED = "could not save the change"

      COMPLAINTS = {
        body: { "blank" => "write the comment first" },
        kind: { Blog::Contract::FORMAT => "pick one of the four link types" },
        other_id: {
          Blog::Contract::FORMAT => "pick a task by its ID",
          "missing" => "that task is gone, so find another",
          "self" => "a task cannot link to itself",
          "taken" => "these two tasks are already linked",
        },
      }.freeze

      class << self
        private

        def add_task_comment(server_context) = server_context.fetch(:add_task_comment)

        def comment_entry(comment)
          {
            id: comment.id,
            body: comment.body,
            author: comment.remote_id ? comment.author : Blog::Owner.full_name,
            source: comment.provider || LOCAL,
            url: comment.url,
            created_at: stamp(comment.created_at),
          }
        end

        def complaint(errors)
          errors.map { |field, (code)| "#{field}: #{reason(field, code)}" }.join("; ")
        end

        def day_or_nil(value) = value && Blog::TimeZone.parse_day(value)

        def link_entry(link) = { label: link.label, id: link.task.id, title: link.task.title, status: link.task.status }

        def link_tasks(server_context) = server_context.fetch(:link_tasks)

        def no_task(id) = refuse(format(NO_TASK, id))

        def reason(field, code)
          return CONTROL if code == Blog::Contract::CONTROL

          COMPLAINTS.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code, code)
        end

        def stamp(time) = time&.utc&.iso8601

        def task_answer(id, server_context, **extra)
          task_reply(task_by_id(server_context).call(id), server_context, **extra)
        end

        def task_by_id(server_context) = server_context.fetch(:task_by_id)

        def task_comments(server_context) = server_context.fetch(:task_comments)

        def task_entry(task, sprint_on = task.sprint&.sprint_date)
          {
            id: task.id,
            title: task.title,
            note: task.note,
            status: task.status,
            list: task.list,
            sprint_on: sprint_on&.iso8601,
          }.merge(ties(task), times(task))
        end

        def task_reply(task, server_context, **extra)
          comments = task_comments(server_context).call(task.id).map { comment_entry(it) }

          answer(task_entry(task).merge(comments:, **extra))
        end

        def ties(task)
          { tags: task.tags.map(&:name), links: task.links.map { link_entry(it) }, blocked: task.blocked? }
        end

        def times(task)
          {
            carried_count: task.carried_count,
            created_at: stamp(task.created_at),
            completed_at: stamp(task.completed_at),
          }
        end

        def unlink_task(server_context) = server_context.fetch(:unlink_task)

        def unread?(value, day) = !value.nil? && day.nil?

        def unsaved = refuse(UNSAVED)

        def window(from, to)
          first, last = [from, to].map { day_or_nil(it) }
          return Failure(BAD_DAY) if unread?(from, first) || unread?(to, last)
          return Failure(BAD_WINDOW) if first && last && first > last

          Success([first, last])
        end
      end
    end
  end
end
