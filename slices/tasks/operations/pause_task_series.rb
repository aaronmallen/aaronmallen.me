# frozen_string_literal: true

module Tasks
  module Operations
    class PauseTaskSeries < Blog::Operation
      include Deps[task_series_mutations: "repos.task_series_mutations"]

      def call(id, at: Time.now) = step affected(task_series_mutations.switch(id, true, at))
    end
  end
end
