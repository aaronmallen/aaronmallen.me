# frozen_string_literal: true

module Posts
  module Relations
    class LinkCheckRuns < Blog::DB::Relation
      schema :link_check_runs, infer: true
    end
  end
end
