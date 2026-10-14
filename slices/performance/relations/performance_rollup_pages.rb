# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceRollupPages < Blog::DB::Relation
      schema :performance_rollup_pages, infer: true
    end
  end
end
