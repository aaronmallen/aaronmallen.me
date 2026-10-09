# frozen_string_literal: true

module Record
  module Relations
    class PullRequests < Blog::DB::Relation
      schema :pull_requests, infer: true
    end
  end
end
