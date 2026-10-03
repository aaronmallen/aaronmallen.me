# frozen_string_literal: true

module Activity
  module Relations
    class WorkSessionDays < Blog::DB::Relation
      schema :work_session_days, infer: true

      def seconds_by_day(from, to)
        worked = where(worked_on: from..to).unordered.select(:worked_on) { integer.sum(seconds).as(:seconds) }

        worked.group(:worked_on).order(:worked_on)
      end
    end
  end
end
