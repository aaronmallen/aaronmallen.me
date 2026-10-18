# frozen_string_literal: true

module Performance
  module Relations
    class PerformanceJobs < Blog::DB::Relation
      schema :performance_jobs, infer: true

      def newest_by_schedule_key(keys)
        wanted = Sequel.function(:unnest, Sequel.pg_array(keys, :text)).as(:wanted, [:schedule_key])
        newest = dataset.unordered.where(schedule_key: Sequel[:wanted][:schedule_key]).reverse(:occurred_at).limit(1)

        dataset.db.from(wanted).cross_join(newest.lateral.as(:newest)).select_all(:newest)
      end
    end
  end
end
