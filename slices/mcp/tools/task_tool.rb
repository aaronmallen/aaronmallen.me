# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class TaskTool < Base
      BAD_DAY = "give from and to as days, such as 2026-01-01"
      BAD_WINDOW = "from comes after to"
      CONTROL = "holds a control character"
      DIRECTIONS = Blog::Types::TaskMove.values.freeze
      LISTS = Blog::Types::TaskFilter.values.freeze
      NO_SPRINT = "no sprint has the ID %s"
      NO_TASK = "no task has the ID %s"
      NO_TYPE = "no task type has the ID %s"
      SEPARATOR = ","
      SPRINT_PAST = "a sprint opens on today or a day after it"
      UNSAVED = "could not save the change"

      COMPLAINTS = {
        color: { Blog::Contract::FORMAT => "pick one of the six colours" },
        icon: { Blog::Contract::FORMAT => "no free solid icon goes by that name" },
        kind: { Blog::Contract::FORMAT => "pick one of the four link types" },
        list: { Blog::Contract::FORMAT => "pick one of the three lists" },
        name: { "blank" => "give the type a name first", "taken" => "another type already holds that name" },
        other_id: {
          Blog::Contract::FORMAT => "pick a task by its ID",
          "missing" => "that task is gone, so find another",
          "self" => "a task cannot link to itself",
          "taken" => "these two tasks are already linked",
        },
        tags: { Blog::Contract::FORMAT => "tags are lowercase words" },
        task_type_id: { Blog::Contract::FORMAT => "pick a type by its ID" },
        title: { "blank" => "write the task down first" },
      }.freeze

      class << self
        private

        def capture_task(server_context) = server_context.fetch(:capture_task)

        def complaint(errors)
          errors.map { |field, (code)| "#{field}: #{reason(field, code)}" }.join("; ")
        end

        def complete_task(server_context) = server_context.fetch(:complete_task)

        def current_sprint(server_context) = server_context.fetch(:current_sprint)

        def day_or_nil(value) = value && Blog::TimeZone.parse_day(value)

        def delete_task(server_context) = server_context.fetch(:delete_task)

        def drop_sprint(server_context) = server_context.fetch(:drop_sprint)

        def find_tasks(server_context) = server_context.fetch(:find_tasks)

        def link_entry(link) = { label: link.label, id: link.task.id, title: link.task.title, status: link.task.status }

        def link_tasks(server_context) = server_context.fetch(:link_tasks)

        def move_task(server_context) = server_context.fetch(:move_task)

        def no_sprint(id) = refuse(format(NO_SPRINT, id))

        def no_task(id) = refuse(format(NO_TASK, id))

        def no_type(id) = refuse(format(NO_TYPE, id))

        def plan_sprint(server_context) = server_context.fetch(:plan_sprint)

        def reason(field, code)
          return CONTROL if code == Blog::Contract::CONTROL

          COMPLAINTS.fetch(field, Dry::Core::Constants::EMPTY_HASH).fetch(code, code)
        end

        def remove_task_type(server_context) = server_context.fetch(:remove_task_type)

        def reopen_task(server_context) = server_context.fetch(:reopen_task)

        def reorder_task(server_context) = server_context.fetch(:reorder_task)

        def reorder_task_type(server_context) = server_context.fetch(:reorder_task_type)

        def save_task(server_context) = server_context.fetch(:save_task)

        def save_task_type(server_context) = server_context.fetch(:save_task_type)

        def schedule_task(server_context) = server_context.fetch(:schedule_task)

        def settled(result, id, server_context)
          case result
          in Success(*) then task_answer(id, server_context)
          in Failure(:not_found) then no_task(id)
          else unsaved
          end
        end

        def sprint_entry(sprint) = { id: sprint.id, date: sprint.sprint_date.iso8601, carried_in: sprint.carried_in }

        def sprint_past = refuse(SPRINT_PAST)

        def sprints_between(server_context) = server_context.fetch(:sprints_between)

        def stamp(time) = time&.utc&.iso8601

        def start_task(server_context) = server_context.fetch(:start_task)

        def tag_text(names) = names.join(SEPARATOR)

        def task_answer(id, server_context, **extra)
          task = task_by_id(server_context).call(id)

          answer(task_entry(task, type_names(server_context)).merge(extra))
        end

        def task_by_id(server_context) = server_context.fetch(:task_by_id)

        def task_counts_by_type(server_context) = server_context.fetch(:task_counts_by_type)

        def task_entry(task, types, sprint_on = task.sprint&.sprint_date)
          {
            id: task.id,
            title: task.title,
            note: task.note,
            status: task.status,
            list: task.list,
            sprint_on: sprint_on&.iso8601,
            task_type: types[task.task_type_id],
            task_type_id: task.task_type_id,
          }.merge(ties(task), times(task))
        end

        def task_types(server_context) = server_context.fetch(:task_types)

        def tasks_in_sprint(server_context) = server_context.fetch(:tasks_in_sprint)

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

        def type_entry(type) = { id: type.id, name: type.name, color: type.color, icon: type.icon }

        def type_names(server_context) = task_types(server_context).call.to_h { [it.id, it.name] }

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
