# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceRequests < Blog::DB::Relation
      schema :performance_requests, infer: true
    end
  end
end
