# frozen_string_literal: true

module Performance
  module Relations
    class PerformancePages < Blog::DB::Relation
      schema :performance_pages, infer: true
    end
  end
end
