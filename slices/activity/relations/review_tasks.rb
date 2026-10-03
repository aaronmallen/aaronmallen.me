# frozen_string_literal: true

module Activity
  module Relations
    class ReviewTasks < Blog::DB::Relation
      DONE = Blog::Types::TaskStatus["done"]
      ONCE = 1

      schema :review_tasks, infer: true

      def carried_between(from, to)
        carried = where(sprint_date: from..to).where(Sequel[:carried_count] >= ONCE)

        carried.order(self[:carried_count].desc, self[:task_id].asc)
      end

      def done_between(from, to)
        where(status: DONE, closed_on: from..to).order(self[:closed_on].asc, self[:task_id].asc)
      end
    end
  end
end
