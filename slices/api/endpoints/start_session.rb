# frozen_string_literal: true

module API
  module Endpoints
    class StartSession < Endpoint
      LIMITS = ::Agents::Contracts::SessionContract

      SCHEMA = {
        additionalProperties: false,
        properties: {
          title: { type: "string", description: "what the session is for, #{LIMITS::TITLE_LIMIT} characters at most" },
          agent: Memory::AUTHOR.fetch(:agent).merge(description: "the agent opening it, such as claude-code"),
          model: Memory::AUTHOR.fetch(:model),
          client: { type: "string", description: "the client the agent runs in, such as Claude Code 2.4 on macOS" },
          repo: Helpers::Schema::REPO.merge(description: "the repository it works in, as owner/name"),
          branch: { type: "string", description: "the branch it works on" },
          tasks: Helpers::Schema.list(Helpers::Schema::TASK).merge(
            maxItems: Blog::Contract::MAX_IDS, description: "the tasks it works on",
          ),
        },
        required: %w[title agent model],
      }.freeze

      REPLY = Helpers::Schema.object(
        { session_id: Helpers::Schema::INTEGER.merge(description: "name it on each memory and artifact write"),
          **Memory::LOADED },
      ).freeze

      CONTRACTS = [::Agents::Contracts::SessionContract].freeze
      COMPLAINTS = {
        **Memory::COMPLAINTS.slice(:agent, :model, :repo),
        branch: { "long" => "keep a branch to #{LIMITS::BRANCH_LIMIT} characters" },
        client: { "long" => "keep a client to #{LIMITS::CLIENT_LIMIT} characters" },
        tasks: { Blog::Contract::MISSING => "name tasks that exist" },
        title: {
          Blog::Contract::BLANK => "name the session first",
          "long" => "keep a title to #{LIMITS::TITLE_LIMIT} characters",
        },
      }.freeze

      include Deps[start_session: "agents.operations.start_session"]

      def handle(tasks: [], repo: nil, **fields)
        case start_session.call({ **fields, repo: Blog::Types::OptionalText[repo]&.downcase, task_ids: tasks })
          in Success[id, files] then Success(session_id: id, **Memory.loaded(files))
          in Failure[:invalid, errors] then rejected(errors.transform_keys(task_ids: :tasks), COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
