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
        "Read everything %s's site keeps: posts, social posts, announcements, webmentions and their settings,",
        "trusted webmention authors, the journal, commits, pull requests and the sync state, API tokens and MCP",
        "clients, tasks, sprints, task rules,",
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
        "included: it reads, marks, tags, snoozes and deletes threads, and lets search and the inbox show them. Only",
        "the agents permission grants agent memory: files of facts that load into each agent's work, their history",
        "and reverts, and artifacts: numbered plans, specs and handoffs kept in versions; deleting a memory file or an",
        "artifact needs delete as well. The tool list holds only what this connection was granted.",
        Tools::Untrusted::WARNING,
      ].join(" ").freeze
      BATCH_OPENING = /\A[ \t\r\n]*\[/
      DAY_PAGED = [Tools::ListCommits, Tools::ListJournalEntries, Tools::ListPullRequests, Tools::ReadActivity].freeze
      PROMPTS = [Prompts::Proofread, Prompts::Report].freeze
      TITLE = "%s's site"
      TOOLS = Tools.constants.sort.map { Tools.const_get(it) }.select { it < Tools::Base }.freeze
      TOOL_ENDPOINTS = API::OperationTable::ENDPOINTS.to_h { [it.to_sym, "api.endpoints.#{it}"] }.freeze

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
        payload.match?(BATCH_OPENING) && JSON.parse(payload).is_a?(Array)
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
