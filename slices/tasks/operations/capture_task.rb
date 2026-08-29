# frozen_string_literal: true

module Tasks
  module Operations
    class CaptureTask < Blog::Operation
      NEXT = Blog::Types::TaskFilter["next"]
      SEPARATOR = ","
      TAG = /(?:\A|\s)#([a-z0-9]+(?:-[a-z0-9]+)*)(?![a-z0-9-])/i
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[
        contract: "contracts.task_contract",
        current_sprint: "operations.current_sprint",
        schedule_task: "operations.schedule_task",
        task_repo: "repos.task_repo",
        task_type_repo: "repos.task_type_repo",
      ]

      def call(params, filter: NEXT, sprint_on: nil)
        fields = step validate(params)
        task = write(fields, filter)
        return [:captured, task] if Blog::Types::TrimmedText[sprint_on].empty?

        step schedule_task.call(task.id, sprint_on)
      end

      private

      def placement(filter)
        return { list: nil, sprint_id: step(current_sprint.call).id } if filter == TODAY

        { list: Blog::Types::TaskList[filter], sprint_id: nil }
      end

      def split(text)
        return [text, Dry::Core::Constants::EMPTY_ARRAY] unless text.is_a?(String)

        [Blog::Whitespace.squish(text.gsub(TAG, " ")), text.scan(TAG).flatten]
      end

      def type_id(value) = value && task_type_repo.by_id(value)&.id

      def validate(params)
        title, tags = split(params[:title])
        result = contract.call(
          title:, list: "", note: "", tags: tags.join(SEPARATOR), task_type_id: params[:task_type_id],
        )

        validated(result)
      end

      def write(fields, filter)
        placed = placement(filter)

        transaction do
          task = task_repo.create(
            title: fields[:title], task_type_id: type_id(fields[:task_type_id]),
            position: task_repo.next_position, **placed,
          )
          task_repo.replace_tags(task.id, fields[:tags])
          task
        end
      end
    end
  end
end
