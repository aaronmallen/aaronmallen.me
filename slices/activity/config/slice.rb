# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/activity"), namespace: Activity)

    export %w[operations.snooze_attention repos.activity_queries repos.attention_queries repos.review_queries]
  end
end
