# frozen_string_literal: true

module Tasks
  module Operations
    class CaptureTask < Operation
      NEXT = Blog::Types::TaskFilter["next"]
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_contract",
        current_sprint: "operations.current_sprint",
        schedule_task: "operations.schedule_task",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
      ]

      def call(params, filter: NEXT, sprint_on: nil)
        fields = step validate(params)
        placed = placement(filter)

        transaction do
          task = write(fields, placed)
          next [:captured, task] if Blog::Types::TrimmedText[sprint_on].empty?

          step schedule_task.call(task.id, sprint_on)
        end
      end

      private

      def placement(filter)
        return { list: nil, sprint_id: step(current_sprint.call).id } if filter == TODAY

        { list: Blog::Types::TaskList[filter], sprint_id: nil }
      end

      def retag(id, names) = task_event_mutations.track(id, Time.now) { task_mutations.replace_tags(id, names) }

      def validate(params)
        validated(contract.call(title: params[:title], list: "", note: params[:note], tags: params[:tags]))
      end

      def write(fields, placed)
        task = task_mutations.append(title: fields[:title], note: fields[:note], **placed)
        retag(task.id, fields[:tags])
        claim_photos.call(PHOTO_OWNER, task.id, task.note)
        task
      end
    end
  end
end
