# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTask < Blog::Operation
      FIELDS = %i[list note tags title].freeze
      OPTIONAL = %i[contributors].freeze
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_contract",
        move_task: "operations.move_task",
        schedule_task: "operations.schedule_task",
        task_contributor_mutations: "repos.task_contributor_mutations",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(id, params)
        task = step find(id)
        fields = step validate(params)

        transaction do
          persist(task, fields)
          credit(id, fields[:contributors])
          step schedule_task.call(id, params[:sprint_on]) if schedules?(task, fields, params[:sprint_on])

          task_queries.by_id(id)
        end
      end

      private

      def credit(id, contributors)
        task_contributor_mutations.replace(id, contributors.map { Blog::Types::Contributor[it] }.uniq) if contributors
      end

      def find(id) = found(task_queries.by_id(id))

      def form(params) = FIELDS.to_h { [it, params[it]] }.merge(params.slice(*OPTIONAL))

      def move(task, list) = moves?(task, list) ? move_task.call(task.id, list) : Success(task)

      def moves?(task, list) = !list.nil? && list != task.place

      def persist(task, fields)
        task_mutations.update(task.id, note: fields[:note], title: fields[:title])
        retag(task.id, fields[:tags])
        claim_photos.call(PHOTO_OWNER, task.id, fields[:note])
        step move(task, fields[:list])
      end

      def retag(id, names) = task_event_mutations.track(id, Time.now) { task_mutations.replace_tags(id, names) }

      def schedules?(task, fields, sprint_on) = !(sprint_on.nil? || moves?(task, fields[:list]))

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
