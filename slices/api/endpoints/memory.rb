# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Memory
      AUTHOR = {
        agent: {
          type: "string",
          description: "the agent making the change, such as claude-code",
        },
        model: { type: "string", description: "the model making the change, such as claude-opus-5-5" },
        session_id: Helpers::Schema::ID.merge(
          description: "the open session start_session gave, to record the change against it; leave it out for none",
        ),
      }.freeze
      DESCRIPTION = {
        type: "string", description: "one line on what the file covers and when to read it",
      }.freeze
      FACT_TYPE = { type: "string", enum: Blog::Types::MemoryFactType.values }.freeze
      FACT_TEXT = { type: "string", description: "the fact" }.freeze
      ID = Helpers::Schema::ID
      LOADS = Helpers::Schema::ID.merge(
        description: "the session start_session gave, to record the files read; an ended one answers but records none",
      ).freeze
      LOADED = {
        files: Helpers::Schema.list(Serializers::LoadedMemoryFile.reference).merge(
          description: "an index of the files in scope without their facts: global, then project and task",
        ),
      }.freeze
      PROJECT = { type: "string", description: "the key of the project to load, such as POD" }.freeze
      REPO = Helpers::Schema::REPO.merge(
        description: "the repository as owner/name, to look up its project; one no project holds gets a new one",
      ).freeze
      SCOPED = "only a %s file takes %s"

      CONTRACTS = [
        ::Agents::Contracts::AuthorContract,
        ::Agents::Contracts::MemoryDescriptionContract,
        ::Agents::Contracts::MemoryFactContract,
        ::Agents::Contracts::MemoryFileContract,
        ::Agents::Contracts::MemoryScopeContract,
      ].freeze
      COMPLAINTS = {
        agent: {
          Blog::Contract::FORMAT => "use a slug such as claude-code",
          Blog::Contract::MISSING => "name the agent along with its model",
          "long" => "keep an agent to #{Blog::Types::CONTRIBUTOR_SLUG_LIMIT} characters",
        },
        model: {
          Blog::Contract::FORMAT => "use a slug such as claude-opus-5-5",
          Blog::Contract::MISSING => "name the model along with its agent",
          "long" => "keep a model to #{Blog::Types::CONTRIBUTOR_SLUG_LIMIT} characters",
        },
        description: {
          Blog::Contract::BLANK => "describe the file in one line",
          Blog::Contract::FORMAT => "keep the description to one line",
        },
        path: {
          Blog::Contract::FORMAT => "use letters, digits, _, ., / and - only",
          "taken" => "a file in this scope already has this path",
        },
        scope: { "taken" => "a file in that scope already has this path" },
        name: { "taken" => "another project has the repo's name; name the project by its key" },
        project: { Blog::Contract::MISSING => "name a project key that exists" },
        project_id: {
          Blog::Contract::MISSING => "a project file needs a project that exists",
          "extra" => format(SCOPED, "project", "project_id"),
        },
        repo: {
          Blog::Contract::FORMAT => "name the repository as owner/name",
        },
        task_id: {
          Blog::Contract::MISSING => "a task file needs a task that exists",
          "extra" => format(SCOPED, "task", "task_id"),
        },
        session_id: {
          Blog::Contract::CLOSED => "that session is not open; start_session opens one",
        },
        text: {
          Blog::Contract::BLANK => "write the fact first",
        },
      }.freeze

      module_function

      def loaded(files) = { files: Serializers::LoadedMemoryFile.new(files).serializable_hash }

      def missing_event(id, event_id) = "memory file #{id} has no history entry with the ID #{event_id}"

      def missing_fact(id, fact_id) = "memory file #{id} has no fact with the ID #{fact_id}"
    end
  end
end
