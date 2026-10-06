# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/activity"), namespace: Activity)

    export %w[
      operations.snooze_attention queries.activity_between queries.activity_commit_totals queries.activity_counts
      queries.activity_counts_by_day queries.activity_counts_by_month queries.activity_day_count
      queries.activity_filters queries.contributor_choices queries.review queries.stalled_list
    ]
  end
end
