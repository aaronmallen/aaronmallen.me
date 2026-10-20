# frozen_string_literal: true

module API
  module Endpoints
    class SearchMemory < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: { type: "string", description: "words to find in the text of live facts" },
          scope: { type: "string", enum: Blog::Types::MemoryScope.values, description: "only files in this scope" },
          repo: Helpers::Schema::REPO.merge(description: "only the global files, the repo's and its projects'"),
          project_id: Memory::ID.merge(description: "only the global files and the project's"),
          task_id: Helpers::Schema::TASK.merge(description: "only the global files and the task's"),
          page: Helpers::Paging::PAGE,
        },
        required: %w[query],
      }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, facts: Helpers::Schema.list(Serializers::MemoryFactHit.reference) },
      ).freeze

      CONTRACTS = Blog::Constants::EMPTY_ARRAY
      BLANK = { query: [Blog::Contract::BLANK] }.freeze
      COMPLAINTS = { **Memory::COMPLAINTS, query: { Blog::Contract::BLANK => "write the words to find" } }.freeze
      MALFORMED = { repo: [Blog::Contract::FORMAT] }.freeze

      include Deps[search_memory: "agents.operations.search_memory"]

      def handle(query:, repo: nil, page: 1, **where)
        text = Blog::Types::OptionalText[query]
        return rejected(BLANK, COMPLAINTS) if text.nil?

        repo = Blog::Types::OptionalText[repo]
        repo &&= Blog::Types::Normalized::Repo.call(repo) { return rejected(MALFORMED, COMPLAINTS) }

        found = search_memory.call(page_of(page), text:, repo:, **where)
        facts = serialized(Serializers::MemoryFactHit, found.rows)

        Success(count: facts.length, facts:, **Helpers::Paging.fields(found))
      end
    end
  end
end
