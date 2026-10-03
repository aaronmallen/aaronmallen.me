# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTask < Blog::Operation
      FIELDS = %i[list note tags title].freeze
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_contract",
        move_task: "operations.move_task",
        schedule_task: "operations.schedule_task",
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
      ]

      def call(id, params)
        task = step find(id)
        fields = step validate(params)

        transaction do
          persist(task, fields)
          step schedule_task.call(id, params[:sprint_on]) if schedules?(task, fields, params[:sprint_on])

          task_repo.by_id(id)
        end
      end

      private

      def find(id) = (task = task_repo.by_id(id)) ? Success(task) : Failure(:not_found)

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def move(task, list) = moves?(task, list) ? move_task.call(task.id, list) : Success(task)

      def moves?(task, list) = !list.nil? && list != task.place

      def persist(task, fields)
        task_repo.update(task.id, note: fields[:note], title: fields[:title])
        retag(task.id, fields[:tags])
        claim_photos.call(PHOTO_OWNER, task.id, fields[:note])
        step move(task, fields[:list])
      end

      def retag(id, names) = task_event_repo.track(id, Time.now) { task_repo.replace_tags(id, names) }

      def schedules?(task, fields, sprint_on) = !(sprint_on.nil? || moves?(task, fields[:list]))

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
