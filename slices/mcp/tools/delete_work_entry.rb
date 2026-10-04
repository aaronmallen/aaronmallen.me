# frozen_string_literal: true

module MCP
  module Tools
    class DeleteWorkEntry < Base
      UNDELETED = "could not remove the role"

      SCHEMA = { additionalProperties: false, properties: { id: API::Schema::ID }, required: ["id"] }.freeze

      description "Remove one role from the work list on /projects for good"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case dep(:delete_work_entry, server_context).call(id)
          in Success(entry) then answer(ListWorkEntries.summary(entry).merge(deleted: true))
          in Failure(:not_found) then refuse("no role has the ID #{id}")
          else refuse(UNDELETED)
          end
        end
      end
    end
  end
end
