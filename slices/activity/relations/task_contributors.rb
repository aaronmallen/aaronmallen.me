# frozen_string_literal: true

module Activity
  module Relations
    class TaskContributors < Blog::DB::Relation
      schema :task_contributors, infer: true

      def named(column) = unordered.exclude(column => nil).select(column).distinct.order(column)
    end
  end
end
