# frozen_string_literal: true

module Tasks
  module Operations
    class ClearTaskCadence < Blog::Operation
      include Deps[task_series_mutations: "repos.task_series_mutations"]

      def call(id) = step affected(task_series_mutations.clear(id))
    end
  end
end
