# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceRollups < Blog::DB::Relation
      schema :performance_rollups, infer: true
    end
  end
end
