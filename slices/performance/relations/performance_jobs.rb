# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceJobs < Blog::DB::Relation
      schema :performance_jobs, infer: true
    end
  end
end
