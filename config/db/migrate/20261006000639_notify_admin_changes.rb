# frozen_string_literal: true

ROM::SQL.migration do
  tables = %w[
    analytics_rollup_clicks analytics_rollup_countries analytics_rollup_devices analytics_rollup_page_countries
    analytics_rollup_page_referrers analytics_rollup_paths analytics_rollup_reach analytics_rollup_referrers
    analytics_rollup_scroll_depths analytics_rollup_sources analytics_rollups attention_snoozes commits
    decision_comments decision_events decision_options decision_tags decisions journal_entries journal_entry_tags
    messages oauth_clients oauth_tokens people photos post_edits post_tags posts project_tags projects record_links
    review_notes saved_views social_post_deliveries social_post_parts social_posts sprints suggestion_edits
    suggestions sync_states tags task_comments task_contributors task_events task_links task_sources
    task_tag_rule_tags task_tag_rules task_tags tasks webmention_settings webmentions work_entries work_sessions
  ]

  up do
    run <<~SQL
      CREATE FUNCTION notify_admin_change() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        IF TG_OP <> 'UPDATE' OR OLD IS DISTINCT FROM NEW THEN
          PERFORM pg_notify('admin_changes', TG_TABLE_NAME);
        END IF;
        RETURN NULL;
      END;
      $$;
    SQL

    tables.each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    tables.each do |table|
      run <<~SQL
        DROP TRIGGER #{table}_notify_admin_change ON #{table};
      SQL
    end

    run <<~SQL
      DROP FUNCTION notify_admin_change();
    SQL
  end
end
