# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskCadence < Blog::Operation
      MOVED = "moved"

      include Deps[
        contract: "contracts.task_cadence_contract",
        recur_task: "operations.recur_task",
        task_queries: "repos.task_queries",
        task_series_mutations: "repos.task_series_mutations",
        task_series_queries: "repos.task_series_queries",
      ]

      def call(id, params, now: Time.now)
        step find(id)
        fields = step validate(params, now)

        transaction do
          task_series_mutations.set(id, cadence(fields), now)
          series = task_series_queries.by_task(id)
          recur_task.call(id, at: now)
          task_series_queries.by_id(series.id)
        end
      end

      private

      def cadence(fields) = fields.slice(:cadence, *Contracts::TaskCadenceContract::FIELDS.fetch(fields[:cadence]))

      def find(id) = found(task_queries.by_id(id)).bind { refused(it) }

      def moved?(task) = !task.series_id.nil? && task_series_queries.by_task(task.id).nil?

      def refused(task)
        return Failure(:imported) if task.source
        return invalid(:cadence, MOVED) if moved?(task)

        Success(task)
      end

      def validate(params, now)
        fields = every_field(params)
        fields[:starts_on] = Blog::TimeZone.today(now) if fields[:starts_on].to_s.empty?

        validated(contract.call(fields))
      end
    end
  end
end
