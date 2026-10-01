# frozen_string_literal: true

require "json"

module MCP
  module Protocol
    class Handler
      BATCH_REFUSAL = JSON.generate(
        jsonrpc: JsonRpcHandler::Version::V2_0,
        id: nil,
        error: {
          code: JsonRpcHandler::ErrorCode::INVALID_REQUEST,
          message: "Invalid Request",
          data: "This server takes one request per POST, not a batch",
        },
      )
      CONTEXT = {
        accept_suggestion_edits: "suggestions.operations.accept_suggestion_edits",
        activity_between: "activity.queries.activity_between",
        activity_commit_totals: "activity.queries.activity_commit_totals",
        activity_counts: "activity.queries.activity_counts",
        activity_counts_by_month: "activity.queries.activity_counts_by_month",
        add_task_comment: "api.endpoints.add_task_comment",
        add_work_entry: "projects.operations.add_work_entry",
        all_tags: "tags.queries.all",
        analytics_between: "analytics.queries.summary_between",
        archive_project: "projects.operations.archive_project",
        archived_projects: "projects.queries.archived",
        cancel_task: "api.endpoints.cancel_task",
        capture_task: "api.endpoints.capture_task",
        commits_between: "record.queries.commits_between",
        commits_last_synced_at: "record.queries.commits_last_synced_at",
        complete_task: "api.endpoints.complete_task",
        compose_announcement: "posts.operations.compose_announcement",
        compose_social_post: "social.operations.compose_social_post",
        create_journal_entry: "api.endpoints.create_journal_entry",
        dated_posts: "posts.queries.dated_between",
        delete_journal_entry: "api.endpoints.delete_journal_entry",
        delete_post: "posts.operations.delete_post",
        delete_social_post: "social.operations.delete_social_post",
        delete_task: "api.endpoints.delete_task",
        delete_work_entry: "projects.operations.delete_work_entry",
        devices_between: "analytics.queries.devices_between",
        drop_sprint: "api.endpoints.drop_sprint",
        editable_social_post: "social.queries.editable_social_post",
        hourly_between: "analytics.queries.hourly_between",
        link_tasks: "api.endpoints.link_tasks",
        list_journal_entries: "api.endpoints.list_journal_entries",
        list_sprints: "api.endpoints.list_sprints",
        list_tasks: "api.endpoints.list_tasks",
        live_projects: "projects.queries.live",
        mark_message: "contact.operations.mark_message",
        matching_tags: "tags.queries.matching",
        message_by_id: "contact.queries.by_id",
        messages_between: "contact.queries.received_between",
        moderate_webmention: "social.operations.moderate_webmention",
        move_project: "projects.operations.move_project",
        move_task: "api.endpoints.move_task",
        navigation_between: "analytics.queries.navigation_between",
        page_between: "analytics.queries.page_between",
        plan_sprint: "api.endpoints.plan_sprint",
        post_by_id: "posts.queries.by_id",
        project_by_id: "projects.queries.by_id",
        published_post_by_slug: "posts.queries.published_by_slug",
        queue_commit_import: "record.operations.queue_commit_import",
        reach_between: "analytics.queries.reach_between",
        read_current_sprint: "api.endpoints.read_current_sprint",
        read_journal_entry: "api.endpoints.read_journal_entry",
        read_spread_between: "analytics.queries.read_spread_between",
        read_task: "api.endpoints.read_task",
        reject_edits: "suggestions.operations.reject_edits",
        remove_tag: "tags.operations.remove_tag",
        reopen_task: "api.endpoints.reopen_task",
        reorder_task: "api.endpoints.reorder_task",
        replace_post_edits: "suggestions.operations.replace_post_edits",
        replace_social_post_edits: "suggestions.operations.replace_social_post_edits",
        restore_project: "projects.operations.restore_project",
        save_post: "posts.operations.save_post",
        save_post_seo: "posts.operations.save_post_seo",
        save_project: "projects.operations.save_project",
        save_tag: "tags.operations.save_tag",
        save_task: "api.endpoints.save_task",
        schedule_task: "api.endpoints.schedule_task",
        scroll_depths_between: "analytics.queries.scroll_depths_between",
        social_posts_dated_between: "social.queries.social_posts_dated_between",
        sources_between: "analytics.queries.sources_between",
        start_task: "api.endpoints.start_task",
        suggestion_by_id: "suggestions.queries.by_id",
        suggestions_between: "suggestions.queries.created_between",
        sync_failures: "record.queries.sync_failures",
        tag_by_id: "tags.queries.by_id",
        tag_usage: "tags.queries.usage",
        unlink_task: "api.endpoints.unlink_task",
        unsent_social_posts: "social.queries.unsent_social_posts",
        update_journal_entry: "api.endpoints.update_journal_entry",
        update_webmention_settings: "social.operations.update_webmention_settings",
        webmention_settings: "social.queries.webmention_settings",
        webmentions_received_in: "social.queries.webmentions_received_in",
        work_entries_between: "projects.queries.work_entries_between",
      }.freeze
      INSTRUCTIONS = [
        "Read everything %s's site keeps: posts, social posts, webmentions, the journal, commits, tasks, sprints,",
        "projects, work history, tags, messages, suggestions, analytics, settings and the whole activity feed.",
        "Suggest edits to a post or social post for the owner to accept or reject in the admin. Make any change the",
        "admin makes, publishing, sending and deleting included. A published post or a sent social post cannot be",
        "called back. The tool list holds only what this connection was granted",
      ].join(" ").freeze
      PROMPTS = [Prompts::Proofread, Prompts::Report].freeze
      TITLE = "%s's writing"
      TOOLS = [
        Tools::AcceptSuggestionEdits,
        Tools::AddTaskComment,
        Tools::AddWorkEntry,
        Tools::ArchiveProject,
        Tools::CancelTask,
        Tools::CaptureTask,
        Tools::CompleteTask,
        Tools::ComposeAnnouncement,
        Tools::CreateJournalEntry,
        Tools::CreatePost,
        Tools::CreateSocialPost,
        Tools::DeleteJournalEntry,
        Tools::DeletePost,
        Tools::DeleteSocialPost,
        Tools::DeleteTask,
        Tools::DeleteWorkEntry,
        Tools::DropSprint,
        Tools::ImportCommits,
        Tools::LinkTasks,
        Tools::ListCommits,
        Tools::ListJournalEntries,
        Tools::ListMessages,
        Tools::ListPosts,
        Tools::ListProjects,
        Tools::ListSocialPosts,
        Tools::ListSprints,
        Tools::ListSuggestions,
        Tools::ListTags,
        Tools::ListTasks,
        Tools::ListWebmentions,
        Tools::ListWorkEntries,
        Tools::MarkMessage,
        Tools::ModerateWebmention,
        Tools::MoveProject,
        Tools::MoveTask,
        Tools::PlanSprint,
        Tools::PublishPost,
        Tools::ReadActivity,
        Tools::ReadAnalytics,
        Tools::ReadCurrentSprint,
        Tools::ReadJournalEntry,
        Tools::ReadMessage,
        Tools::ReadPost,
        Tools::ReadSocialPost,
        Tools::ReadSyncState,
        Tools::ReadTask,
        Tools::ReadWebmentionSettings,
        Tools::RejectSuggestionEdits,
        Tools::RemoveTag,
        Tools::ReopenTask,
        Tools::ReorderTask,
        Tools::RestoreProject,
        Tools::SaveProject,
        Tools::SaveTag,
        Tools::SaveTask,
        Tools::ScheduleTask,
        Tools::SendSocialPost,
        Tools::StartTask,
        Tools::SuggestEdits,
        Tools::SummarizeActivity,
        Tools::UnlinkTask,
        Tools::UpdateJournalEntry,
        Tools::UpdatePost,
        Tools::UpdateSocialPost,
        Tools::UpdateWebmentionSettings,
        Tools::WritePostSeo,
      ].freeze

      include Deps["settings", honeybadger: "honeybadger.agent", **CONTEXT]

      def call(payload, scopes:) = batch?(payload) ? BATCH_REFUSAL : server(scopes).handle_json(payload)

      private

      def batch?(payload)
        JSON.parse(payload).is_a?(Array)
      rescue JSON::ParserError
        false
      end

      def context = CONTEXT.keys.to_h { [it, public_send(it)] }.merge(page_size: settings.page_size[:mcp])

      def name = Blog::Types::Normalized::Host.call(settings.site[:url])

      def owner = settings.owner[:name]

      def report(error, _context)
        honeybadger.notify(error) unless error.is_a?(Server::RequestHandlerError)
      end

      def server(scopes)
        ScopedServer.new(
          configuration: Configuration.new(exception_reporter: method(:report)),
          instructions: format(INSTRUCTIONS, owner),
          name:,
          prompts: PROMPTS,
          scopes:,
          server_context: context,
          title: format(TITLE, owner),
          tools: TOOLS,
          version: Blog::Version::CURRENT,
        )
      end
    end
  end
end
