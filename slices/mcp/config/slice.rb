# frozen_string_literal: true

require "mcp"

module MCP
  class Slice < Hanami::Slice
    OAUTH_PREFIX = "/oauth"
    RESOURCE_PATH = "/mcp"

    config.no_auto_register_paths += %w[prompts tools]

    config.shared_app_component_keys += %w[assets honeybadger.agent]

    config.actions.content_security_policy[:frame_ancestors] = "'none'"
    config.actions.content_security_policy[:form_action] = "'self' https: http:"

    config.actions.csrf_protection = false

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[auth.session_reader], from: :admin

    import from: :api

    import keys: %w[
      operations.hash_visitor repos.analytics_event_queries repos.analytics_page_queries repos.analytics_rollup_queries
      repos.feed_fetch_queries repos.post_reader_queries
    ], from: :analytics

    import keys: %w[operations.read_photo], from: :media

    import keys: %w[
      operations.mark_message repos.message_queries
    ], from: :contact

    import keys: %w[
      operations.compose_announcement operations.delete_post operations.save_post operations.save_post_seo
      repos.post_queries
    ], from: :posts

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry
      operations.restore_project operations.save_project repos.project_queries repos.work_entry_queries
    ], from: :projects

    import keys: %w[
      operations.queue_commit_import repos.commit_queries repos.pull_request_queries repos.sync_state_queries
    ], from: :record

    import keys: %w[
      operations.moderate_webmention operations.update_webmention_settings repos.social_post_queries
      repos.webmention_queries
    ], from: :social

    import keys: %w[operations.record_sighting], from: :security

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits operations.replace_post_edits
      operations.replace_social_post_edits repos.suggestion_queries
    ], from: :suggestions

    import keys: %w[operations.remove_tag operations.save_tag repos.tag_queries], from: :tags

    import keys: %w[operations.link_repo_tasks repos.task_source_queries], from: :tasks

    export %w[operations.revoke_client repos.oauth_client_queries]
  end
end
