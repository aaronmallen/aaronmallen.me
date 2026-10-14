# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceRollupRequests < Blog::DB::Relation
      schema :performance_rollup_requests, infer: true
    end
  end
end
