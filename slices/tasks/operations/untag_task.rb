# frozen_string_literal: true

module Tasks
  module Operations
    class UntagTask < Blog::Operation
      include Deps[
        task_event_mutations: "repos.task_event_mutations",
        task_queries: "repos.task_queries",
        task_tag_mutations: "repos.task_tag_mutations",
      ]

      def call(id, name, at: Time.now)
        step find(id)

        task_event_mutations.track(id, at) { task_tag_mutations.remove(id, name) }
        task_queries.by_id(id)
      end

      private

      def find(id) = found(task_queries.exist?(id) && id)
    end
  end
end
