# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceRollupJobs < Blog::DB::Relation
      schema :performance_rollup_jobs, infer: true
    end
  end
end
