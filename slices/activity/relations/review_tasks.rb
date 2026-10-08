# frozen_string_literal: true

module Activity
  module Relations
    class ReviewTasks < Blog::DB::Relation
      use :crediting

      DONE = Blog::Types::TaskStatus["done"]

      schema :review_tasks, infer: true

      def done_between(from, to)
        where(status: DONE, closed_on: from..to).order(self[:closed_on].asc, self[:task_id].asc)
      end
    end
  end
end
