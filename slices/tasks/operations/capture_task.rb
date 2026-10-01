# frozen_string_literal: true

module Tasks
  module Operations
    class CaptureTask < Blog::Operation
      NEXT = Blog::Types::TaskFilter["next"]
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_contract",
        current_sprint: "operations.current_sprint",
        schedule_task: "operations.schedule_task",
        task_repo: "repos.task_repo",
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

      def validate(params)
        validated(contract.call(title: params[:title], list: "", note: params[:note], tags: params[:tags]))
      end

      def write(fields, filter)
        placed = placement(filter)

        transaction do
          task = task_repo.append(title: fields[:title], note: fields[:note], **placed)
          task_repo.replace_tags(task.id, fields[:tags])
          claim_photos.call(PHOTO_OWNER, task.id, task.note)
          task
        end
      end
    end
  end
end
