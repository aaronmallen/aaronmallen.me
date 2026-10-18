# frozen_string_literal: true

module API
  module Endpoints
    class DeleteWorkEntry < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::WorkEntry::SCHEMA, deleted: Helpers::Schema::BOOLEAN).freeze

      include Deps[delete_work_entry: "projects.operations.delete_work_entry"]

      def handle(id:)
        case delete_work_entry.call(id)
          in Success(entry) then Success(serialized(Serializers::WorkEntry, entry).merge(deleted: true))
          in Failure(:not_found) then missing("role", id)
          in unmatched then unhandled(unmatched, "could not remove the role")
        end
      end
    end
  end
end
