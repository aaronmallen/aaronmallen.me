# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:performance_jobs) do
      add_column :schedule_key, :non_blank_text
      add_index %i[schedule_key occurred_at]
    end

    keys = {
      "Analytics::Jobs::RefreshCountryDatabase" => "refresh_country_database",
      "Analytics::Jobs::RollUpAnalytics" => "roll_up_analytics",
      "Backups::Jobs::BackUpDatabase" => "back_up_database",
      "Calendar::Jobs::SyncCalendar" => "sync_calendar",
      "Health::Jobs::QueueHeldBackfills" => "queue_held_backfills",
      "Health::Jobs::SyncHealth" => "sync_health",
      "MCP::Jobs::ReapExpiredCredentials" => "reap_expired_credentials",
      "Mail::Jobs::ReapSpamMessages" => "reap_spam_messages",
      "Mail::Jobs::SyncGmail" => "sync_gmail",
      "Media::Jobs::SweepPhotos" => "sweep_photos",
      "Performance::Jobs::RollUpTiming" => "roll_up_timing",
      "Posts::Jobs::CheckPostLinks" => "check_post_links",
      "Posts::Jobs::PublishDuePosts" => "publish_due_posts",
      "Posts::Jobs::QueueHeldFollowUps" => "queue_held_follow_ups",
      "Posts::Jobs::RerenderPosts" => "rerender_posts",
      "Projects::Jobs::RefreshProjects" => "refresh_projects",
      "Record::Jobs::ImportCommits" => "import_commits",
      "Record::Jobs::ImportPullRequests" => "import_pull_requests",
      "Record::Jobs::ReapSyncStates" => "reap_sync_states",
      "Search::Jobs::ReapSearchAttempts" => "reap_search_attempts",
      "Security::Jobs::PruneAccessRecords" => "prune_access_records",
      "Shares::Jobs::QueueHeldTitleFetches" => "queue_held_title_fetches",
      "Social::Jobs::QueueHeldWebmentions" => "queue_held_webmentions",
      "Social::Jobs::ReapWebmentionReceipts" => "reap_webmention_receipts",
      "Social::Jobs::RefreshSocialEngagement" => "refresh_social_engagement",
      "Social::Jobs::SendDueSocialPosts" => "send_due_social_posts",
      "Tasks::Jobs::RollOverSprint" => "roll_over_sprint",
    }
    from(:performance_jobs).where(job: keys.keys).update(schedule_key: Sequel.case(keys, nil, :job))
  end

  down do
    alter_table(:performance_jobs) { drop_column :schedule_key }
  end
end
