# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    export %w[
      queries.activity_between queries.activity_commit_totals queries.activity_counts
      queries.activity_counts_by_day queries.activity_counts_by_month queries.activity_day_count queries.stalled_list
    ]
  end
end
