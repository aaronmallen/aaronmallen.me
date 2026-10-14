# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskCadence < Blog::Operation
      include Deps[
        contract: "contracts.task_cadence_contract",
        task_queries: "repos.task_queries",
        task_series_mutations: "repos.task_series_mutations",
        task_series_queries: "repos.task_series_queries",
      ]

      def call(id, params, now: Time.now)
        step find(id)
        fields = step validate(params, now)

        task_series_mutations.set(id, cadence(fields), now)
        task_series_queries.by_task(id)
      end

      private

      def cadence(fields) = fields.slice(:cadence, *Contracts::TaskCadenceContract::FIELDS.fetch(fields[:cadence]))

      def find(id) = found(task_queries.by_id(id)).bind { it.source ? Failure(:imported) : Success(it) }

      def validate(params, now)
        fields = every_field(params)
        fields[:starts_on] = Blog::TimeZone.today(now) if fields[:starts_on].to_s.empty?

        validated(contract.call(fields))
      end
    end
  end
end
