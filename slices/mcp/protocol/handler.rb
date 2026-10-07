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
        add_work_entry: "projects.operations.add_work_entry",
        analytics_event_queries: "analytics.repos.analytics_event_queries",
        analytics_page_queries: "analytics.repos.analytics_page_queries",
        analytics_rollup_queries: "analytics.repos.analytics_rollup_queries",
        archive_project: "projects.operations.archive_project",
        commit_queries: "record.repos.commit_queries",
        compose_announcement: "posts.operations.compose_announcement",
        compose_social_post: "social.operations.compose_social_post",
        connected_clients: "queries.connected_clients",
        delete_post: "posts.operations.delete_post",
        delete_social_post: "social.operations.delete_social_post",
        delete_work_entry: "projects.operations.delete_work_entry",
        feed_fetch_queries: "analytics.repos.feed_fetch_queries",
        granted_scopes: "queries.granted_scopes",
        link_repo_tasks: "tasks.operations.link_repo_tasks",
        live_tokens: "api.queries.live_tokens",
        mark_message: "contact.operations.mark_message",
        measure_parts: "social.operations.measure_parts",
        message_queries: "contact.repos.message_queries",
        moderate_webmention: "social.operations.moderate_webmention",
        post_figures: "api.queries.post_figures",
        post_reader_queries: "analytics.repos.post_reader_queries",
        post_queries: "posts.repos.post_queries",
        project_queries: "projects.repos.project_queries",
        queue_commit_import: "record.operations.queue_commit_import",
        read_photo: "media.operations.read_photo",
        reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits",
        remove_tag: "tags.operations.remove_tag",
        replace_post_edits: "suggestions.operations.replace_post_edits",
        replace_social_post_edits: "suggestions.operations.replace_social_post_edits",
        restore_project: "projects.operations.restore_project",
        save_post: "posts.operations.save_post",
        save_post_seo: "posts.operations.save_post_seo",
        save_project: "projects.operations.save_project",
        save_tag: "tags.operations.save_tag",
        social_post_queries: "social.repos.social_post_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
        sync_state_queries: "record.repos.sync_state_queries",
        tag_queries: "tags.repos.tag_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        update_webmention_settings: "social.operations.update_webmention_settings",
        webmention_queries: "social.repos.webmention_queries",
        work_entry_queries: "projects.repos.work_entry_queries",
      }.freeze
      INSTRUCTIONS = [
        "Read everything %s's site keeps: posts, social posts, announcements, webmentions and their settings,",
        "the journal, commits and the sync state, API tokens and MCP clients, tasks, sprints, task rules, work",
        "sessions and the time report, projects, work history, decisions, people, tags, record links, saved views,",
        "messages, photos, the inbox, attention, the calendar, the review, suggestions, analytics and the whole",
        "activity feed. Search every kind by its words, and look up accounts on Mastodon and Bluesky. Suggest edits to",
        "a post or social post, and settle suggestions with accept_suggestion_edits and reject_suggestion_edits or",
        "leave them for the owner in the admin. Make any change the admin makes, save minting and revoking API tokens",
        "and MCP clients. The write permission grants edits, publish grants publishing posts and sending social posts,",
        "and delete grants every tool that removes a record for good. A published post or a sent social post cannot be",
        "called back. The tool list holds only what this connection was granted.",
        Tools::Untrusted::WARNING,
      ].join(" ").freeze
      PROMPTS = [Prompts::Proofread, Prompts::Report].freeze
      SPLIT_ENDPOINTS = %i[create_person create_task_rule update_person update_task_rule].freeze
      TITLE = "%s's site"
      TOOLS = [
        Tools::AcceptSuggestionEdits,
        Tools::AddDecisionComment,
        Tools::AddDecisionOption,
        Tools::AddTaskComment,
        Tools::AddWorkEntry,
        Tools::ApproveWebmentions,
        Tools::ArchiveProject,
        Tools::CancelTask,
        Tools::CancelTasks,
        Tools::CaptureTask,
        Tools::ClearInbox,
        Tools::CompleteTask,
        Tools::CompleteTasks,
        Tools::ComposeAnnouncement,
        Tools::CreateJournalEntry,
        Tools::CreatePost,
        Tools::CreateSavedView,
        Tools::CreateSocialPost,
        Tools::DeleteDecisionComment,
        Tools::DeleteDecisionOption,
        Tools::DeleteJournalEntry,
        Tools::DeleteMessages,
        Tools::DeletePerson,
        Tools::DeletePost,
        Tools::DeletePosts,
        Tools::DeleteSavedView,
        Tools::DeleteSocialPost,
        Tools::DeleteTask,
        Tools::DeleteTaskComment,
        Tools::DeleteTaskRule,
        Tools::DeleteTasks,
        Tools::DeleteWorkEntry,
        Tools::DeleteWorkSession,
        Tools::DropDecision,
        Tools::DropSprint,
        Tools::EditDecision,
        Tools::EditDecisionComment,
        Tools::EditDecisionOption,
        Tools::EditTaskComment,
        Tools::IgnoreWebmentions,
        Tools::ImportCommits,
        Tools::LinkRecords,
        Tools::LinkTasks,
        Tools::ListAPITokens,
        Tools::ListAttention,
        Tools::ListCalendar,
        Tools::ListClients,
        Tools::ListCommits,
        Tools::ListDecisions,
        Tools::ListInbox,
        Tools::ListJournalEntries,
        Tools::ListLinks,
        Tools::ListMessages,
        Tools::ListPeople,
        Tools::ListPosts,
        Tools::ListProjects,
        Tools::ListSavedViews,
        Tools::ListSocialPosts,
        Tools::ListSprints,
        Tools::ListSuggestions,
        Tools::ListTags,
        Tools::ListTaskRules,
        Tools::ListTasks,
        Tools::ListWebmentions,
        Tools::ListWorkEntries,
        Tools::MarkMessage,
        Tools::MarkMessagesRead,
        Tools::MarkMessagesUnread,
        Tools::MarkTaskSeen,
        Tools::MarkWebmentionsSpam,
        Tools::ModerateWebmention,
        Tools::MoveTask,
        Tools::MoveTasks,
        Tools::OpenDecision,
        Tools::PauseTask,
        Tools::PlanSprint,
        Tools::PublishPost,
        Tools::ReadActivity,
        Tools::ReadAnalytics,
        Tools::ReadCommit,
        Tools::ReadCurrentSprint,
        Tools::ReadDecision,
        Tools::ReadJournalEntry,
        Tools::ReadMessage,
        Tools::ReadPerson,
        Tools::ReadPhoto,
        Tools::ReadPost,
        Tools::ReadProject,
        Tools::ReadReview,
        Tools::ReadSavedView,
        Tools::ReadSocialPost,
        Tools::ReadSyncState,
        Tools::ReadTag,
        Tools::ReadTask,
        Tools::ReadTimeReport,
        Tools::ReadWebmention,
        Tools::ReadWebmentionSettings,
        Tools::ReadWorkEntry,
        Tools::RejectSuggestionEdits,
        Tools::RemoveTag,
        Tools::ReopenDecision,
        Tools::ReopenTask,
        Tools::ReorderTask,
        Tools::ResolveDecision,
        Tools::RestoreProject,
        Tools::SavePerson,
        Tools::SaveProject,
        Tools::SaveReviewNote,
        Tools::SaveTag,
        Tools::SaveTask,
        Tools::SaveTaskRule,
        Tools::ScheduleTask,
        Tools::Search,
        Tools::SearchAccounts,
        Tools::SendSocialPost,
        Tools::SetTaskTotal,
        Tools::SnoozeAttention,
        Tools::SnoozeInbox,
        Tools::SnoozeInboxRow,
        Tools::StartTask,
        Tools::SuggestEdits,
        Tools::SummarizeActivity,
        Tools::SyncIssues,
        Tools::TagDecision,
        Tools::TagPosts,
        Tools::TagTasks,
        Tools::UnlinkRecords,
        Tools::UnlinkTask,
        Tools::UntagDecision,
        Tools::UntagTasks,
        Tools::UpdateJournalEntry,
        Tools::UpdatePost,
        Tools::UpdatePostEditNote,
        Tools::UpdateSavedView,
        Tools::UpdateSocialPost,
        Tools::UpdateWebmentionSettings,
        Tools::UpdateWorkSession,
        Tools::UploadPhoto,
        Tools::WakeInboxRow,
        Tools::WritePostSeo,
      ].freeze
      TOOL_ENDPOINTS = TOOLS.filter_map(&:endpoint_key).union(SPLIT_ENDPOINTS)
                            .to_h { [it, "api.endpoints.#{it}"] }.freeze

      include Deps["settings", honeybadger: "honeybadger.agent", **CONTEXT, **TOOL_ENDPOINTS]

      def call(payload, scopes:, oauth_client_id:)
        batch?(payload) ? BATCH_REFUSAL : server(scopes, oauth_client_id).handle_json(payload)
      end

      private

      def batch?(payload)
        JSON.parse(payload).is_a?(Array)
      rescue JSON::ParserError
        false
      end

      def context(oauth_client_id)
        endpoints = CONTEXT.merge(TOOL_ENDPOINTS).keys.to_h { [it, public_send(it)] }
        endpoints.merge(oauth_client_id:, page_size: settings.page_size[:mcp])
      end

      def name = Blog::Types::Normalized::Host.call(settings.site[:url])

      def owner = settings.owner[:name]

      def report(error, _context)
        honeybadger.notify(error) unless error.is_a?(Server::RequestHandlerError)
      end

      def server(scopes, oauth_client_id)
        ScopedServer.new(
          configuration: Configuration.new(exception_reporter: method(:report)),
          instructions: format(INSTRUCTIONS, owner),
          name:,
          prompts: PROMPTS,
          scopes:,
          server_context: context(oauth_client_id),
          title: format(TITLE, owner),
          tools: TOOLS,
          version: Blog::Version::CURRENT,
        )
      end
    end
  end
end
