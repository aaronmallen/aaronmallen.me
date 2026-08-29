# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTask < Blog::Operation
      FIELDS = %i[list note tags task_type_id title].freeze

      include Deps[
        contract: "contracts.task_contract",
        move_task: "operations.move_task",
        schedule_task: "operations.schedule_task",
        task_repo: "repos.task_repo",
        task_type_repo: "repos.task_type_repo",
      ]

      def call(id, params)
        task = step find(id)
        fields = step validate(params)
        saved = persist(task, fields)
        return saved if moves?(task, fields[:list]) || params[:sprint_on].nil?

        step schedule_task.call(id, params[:sprint_on])
        task_repo.by_id(id)
      end

      private

      def find(id) = (task = task_repo.by_id(id)) ? Success(task) : Failure(:not_found)

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def move(task, list) = moves?(task, list) ? move_task.call(task.id, list) : Success(task)

      def moves?(task, list) = !list.nil? && list != task.place

      def persist(task, fields)
        transaction do
          rewrite(task, fields)
          step move(task, fields[:list])

          task_repo.by_id(task.id)
        end
      end

      def rewrite(task, fields)
        task_repo.update(
          task.id, note: fields[:note], title: fields[:title], task_type_id: type_id(fields[:task_type_id]),
        )
        task_repo.replace_tags(task.id, fields[:tags])
      end

      def type_id(value) = value && task_type_repo.by_id(value)&.id

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
