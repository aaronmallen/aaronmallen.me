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
      INSTRUCTIONS = [
        "Read everything %s's site keeps: posts, social posts, announcements, webmentions and their settings, the",
        "journal, commits, pull requests and the sync state, API tokens and MCP clients, tasks, sprints, task rules,",
        "work sessions and the time report, projects, work history, decisions, people, tags, record links, saved",
        "views, photos, shares, the inbox, attention, the calendar, the review, suggestions, analytics, performance",
        "timing and the whole activity feed. Search every kind by its words, and look up accounts on Mastodon and",
        "Bluesky. Suggest edits to a post or social post, and settle suggestions with accept_suggestion_edits and",
        "reject_suggestion_edits or",
        "leave them for the owner in the admin. Make any change the admin makes, save minting and revoking API tokens",
        "and MCP clients. The write permission grants edits, publish grants publishing posts and sending social posts,",
        "and every change that shows in public: shares, public projects, tasks on a published board, published and",
        "scheduled posts, work history, approved webmentions and webmention settings. Delete grants every tool that",
        "removes a record for good. A published",
        "post or a sent social post cannot be called back. Only the health permission grants the owner's health days,",
        "workouts and their patterns. Only the mail permission grants mail from every account, contact form messages",
        "included: it reads, marks, tags, snoozes and deletes threads, and lets search and the inbox show them. The",
        "tool list holds only what this connection was granted.",
        Tools::Untrusted::WARNING,
      ].join(" ").freeze
      DAY_PAGED = [Tools::ListCommits, Tools::ListJournalEntries, Tools::ListPullRequests, Tools::ReadActivity].freeze
      PROMPTS = [Prompts::Proofread, Prompts::Report].freeze
      SPLIT_ENDPOINTS = %i[
        create_person create_project create_tag create_task_rule update_person update_project update_tag
        update_task_rule
      ].freeze
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
        Tools::DeleteMailThreads,
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
        Tools::ListMailThreads,
        Tools::ListPeople,
        Tools::ListPosts,
        Tools::ListProjects,
        Tools::ListPullRequests,
        Tools::ListSavedViews,
        Tools::ListShareGroups,
        Tools::ListShares,
        Tools::ListSocialPosts,
        Tools::ListSprints,
        Tools::ListSuggestions,
        Tools::ListTags,
        Tools::ListTaskRules,
        Tools::ListTaskSeries,
        Tools::ListTasks,
        Tools::ListWebmentions,
        Tools::ListWorkEntries,
        Tools::MarkMailThread,
        Tools::MarkMailThreadsRead,
        Tools::MarkMailThreadsUnread,
        Tools::MarkTaskSeen,
        Tools::MarkWebmentionsSpam,
        Tools::ModerateWebmention,
        Tools::MoveTask,
        Tools::MoveTasks,
        Tools::OpenDecision,
        Tools::PauseTask,
        Tools::PauseTaskSeries,
        Tools::PlanSprint,
        Tools::PublishPost,
        Tools::ReadActivity,
        Tools::ReadAnalytics,
        Tools::ReadCommit,
        Tools::ReadCurrentSprint,
        Tools::ReadDecision,
        Tools::ReadHealthDays,
        Tools::ReadJournalEntry,
        Tools::ReadMailThread,
        Tools::ReadPerformance,
        Tools::ReadPerson,
        Tools::ReadPhoto,
        Tools::ReadPost,
        Tools::ReadProject,
        Tools::ReadPullRequest,
        Tools::ReadReview,
        Tools::ReadSavedView,
        Tools::ReadShare,
        Tools::ReadShareGroup,
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
        Tools::ResumeTaskSeries,
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
        Tools::SnoozeMailThreads,
        Tools::StageTask,
        Tools::StartTask,
        Tools::SuggestEdits,
        Tools::SummarizeActivity,
        Tools::SyncIssues,
        Tools::TagDecision,
        Tools::TagMailThreads,
        Tools::TagPosts,
        Tools::TagTasks,
        Tools::UnlinkRecords,
        Tools::UnlinkTask,
        Tools::UntagDecision,
        Tools::UntagMailThreads,
        Tools::UntagTasks,
        Tools::UpdateJournalEntry,
        Tools::UpdatePost,
        Tools::UpdatePostEditNote,
        Tools::UpdateSavedView,
        Tools::UpdateShare,
        Tools::UpdateShareGroup,
        Tools::UpdateShareGroupFile,
        Tools::UpdateSocialPost,
        Tools::UpdateWebmentionSettings,
        Tools::UpdateWorkSession,
        Tools::UploadPhoto,
        Tools::UploadShare,
        Tools::UploadShareGroup,
        Tools::WakeInboxRow,
        Tools::WritePostSeo,
      ].freeze
      TOOL_ENDPOINTS = TOOLS.filter_map(&:endpoint_key).union(SPLIT_ENDPOINTS)
                            .to_h { [it, "api.endpoints.#{it}"] }.freeze

      include Deps[
        "settings",
        honeybadger: "honeybadger.agent",
        task_source_queries: "tasks.repos.task_source_queries",
        **TOOL_ENDPOINTS,
      ]

      def call(payload, scopes:, oauth_client_id:)
        batch?(payload) ? BATCH_REFUSAL : server(scopes, oauth_client_id).handle_json(payload)
      end

      private

      def batch?(payload)
        JSON.parse(payload).is_a?(Array)
      rescue JSON::ParserError
        false
      end

      def context(scopes, oauth_client_id)
        endpoints = TOOL_ENDPOINTS.keys.to_h { [it, public_send(it)] }
        endpoints.merge(oauth_client_id:, scopes:, task_source_queries:)
      end

      def descriptions
        paged = DAY_PAGED.to_h { [it.name_value, it.described(page_size: settings.page_size[:mcp])] }

        paged.merge(Tools::ReadAnalytics.name_value => Tools::ReadAnalytics.described(settings.analytics))
      end

      def name = Blog::Types::Normalized::Host.call(settings.site[:url])

      def owner = settings.owner_name

      def report(error, _context)
        honeybadger.notify(error) unless error.is_a?(Server::RequestHandlerError)
      end

      def server(scopes, oauth_client_id)
        ScopedServer.new(
          configuration: Configuration.new(exception_reporter: method(:report)),
          descriptions:,
          instructions: format(INSTRUCTIONS, owner),
          name:,
          prompts: PROMPTS,
          scopes:,
          server_context: context(scopes, oauth_client_id),
          title: format(TITLE, owner),
          tools: TOOLS,
          version: Blog::Version::CURRENT,
        )
      end
    end
  end
end
