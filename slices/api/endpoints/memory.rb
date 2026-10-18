# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Memory
      AUTHOR = {
        agent: {
          type: "string",
          description: "the agent making the change, such as claude-code; leave agent and model out for the owner",
        },
        model: { type: "string", description: "the model making the change, such as claude-opus-5-5" },
        session_id: Helpers::Schema::ID.merge(
          description: "the open session start_session gave, to record the change against it; leave it out for none",
        ),
      }.freeze
      FACT_TYPE = { type: "string", enum: Blog::Types::MemoryFactType.values }.freeze
      FACT_TEXT = {
        type: "string",
        description: "the fact, #{::Agents::Contracts::MemoryFactContract::TEXT_LIMIT} characters at most",
      }.freeze
      ID = Helpers::Schema::ID
      LOADED = {
        markdown: {
          type: "string",
          description: "the files as an agent loads them; marked untrusted when an agent wrote any of the facts",
        },
        files: Helpers::Schema.list(Serializers::MemoryFile.reference).merge(
          description: "the files that loaded: global, then repo, project and task",
        ),
      }.freeze
      PAIRED = "give agent and model together"
      SCOPED = "only a %s file takes %s"

      COMPLAINTS = {
        agent: { Blog::Contract::MISSING => PAIRED, Blog::Contract::FORMAT => "use a slug such as claude-code" },
        model: { Blog::Contract::MISSING => PAIRED, Blog::Contract::FORMAT => "use a slug such as claude-opus-5-5" },
        path: {
          Blog::Contract::FORMAT => "use letters, digits, _, ., / and - only",
          "taken" => "a file in this scope already has this path",
        },
        scope: { "taken" => "a file in that scope already has this path" },
        project_id: {
          Blog::Contract::MISSING => "a project file needs a project that exists",
          "extra" => format(SCOPED, "project", "project_id"),
        },
        repo: {
          Blog::Contract::FORMAT => "name the repository as owner/name",
          Blog::Contract::MISSING => "a repo file needs a repo",
          "extra" => format(SCOPED, "repo", "repo"),
        },
        task_id: {
          Blog::Contract::MISSING => "a task file needs a task that exists",
          "extra" => format(SCOPED, "task", "task_id"),
        },
        session_id: {
          ::Agents::Operations::TouchSession::CLOSED => "that session is not open; start_session opens one",
        },
        text: {
          Blog::Contract::BLANK => "write the fact first",
          "long" => "keep a fact to #{::Agents::Contracts::MemoryFactContract::TEXT_LIMIT} characters",
        },
      }.freeze

      module_function

      def loaded(files)
        markdown = files.map(&:markdown).join("\n")

        {
          markdown: files.any?(&:agent_written?) ? Helpers::Untrusted.call(markdown) : markdown,
          files: Serializers::MemoryFile.new(files).serializable_hash,
        }
      end

      def missing_event(id, event_id) = "memory file #{id} has no history entry with the ID #{event_id}"

      def missing_fact(id, fact_id) = "memory file #{id} has no fact with the ID #{fact_id}"
    end
  end
end
