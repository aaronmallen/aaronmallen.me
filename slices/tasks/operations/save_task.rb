# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTask < Blog::Operation
      FIELDS = %i[list note tags title].freeze
      OPTIONAL = %i[contributors].freeze
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        clear_task_cadence: "operations.clear_task_cadence",
        contract: "contracts.task_contract",
        move_task: "operations.move_task",
        schedule_task: "operations.schedule_task",
        set_task_cadence: "operations.set_task_cadence",
        task_contributor_mutations: "repos.task_contributor_mutations",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(id, params)
        task = step find(id)
        fields = step validate(params)

        moves = moves?(task, fields[:list], params[:sprint_on])

        transaction do
          persist(task, fields, moves)
          step recur(id, params)
          step schedule(id, params[:sprint_on]) unless moves

          task_queries.by_id(id)
        end
      end

      private

      def credit(id, contributors)
        task_contributor_mutations.replace(id, contributors.map { Blog::Types::Contributor[it] }.uniq) if contributors
      end

      def find(id) = found(task_queries.detailed(id))

      def form(params) = FIELDS.to_h { [it, params[it]] }.merge(params.slice(*OPTIONAL))

      def moves?(task, list, sprint_on)
        return false if list.nil?

        list != task.place || (sprint_on.nil? && task.ahead?(Blog::TimeZone.today))
      end

      def persist(task, fields, moves)
        task_mutations.update(task.id, note: fields[:note], title: fields[:title])
        credit(task.id, fields[:contributors])
        retag(task.id, fields[:tags])
        claim_photos.call(PHOTO_OWNER, task.id, fields[:note])
        step move_task.call(task.id, fields[:list]) if moves
      end

      def recur(id, params)
        return Success() unless params.key?(:recur)

        recur = Blog::Types::Fields[params[:recur]]
        return set_task_cadence.call(id, recur) unless Blog::Types::Text[recur[:cadence]].empty?

        clear_task_cadence.call(id)
        Success()
      end

      def retag(id, names) = task_event_mutations.track(id, Time.now) { task_mutations.replace_tags(id, names) }

      def schedule(id, sprint_on) = sprint_on.nil? ? Success() : schedule_task.call(id, sprint_on)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
