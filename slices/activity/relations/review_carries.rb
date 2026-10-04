# frozen_string_literal: true

module Activity
  module Relations
    class ReviewCarries < Blog::DB::Relation
      schema :review_carries, infer: true

      def per_task_between(from, to)
        carries = where(sprint_date: from..to).unordered.select(:task_id, :title) do
          [integer.count(event_id).as(:carried_count), date.max(sprint_date).as(:sprint_date)]
        end

        carries.group(:task_id, :title).order(Sequel.desc(:carried_count), :task_id)
      end
    end
  end
end
