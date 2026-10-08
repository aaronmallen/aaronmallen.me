# frozen_string_literal: true

module API
  module Endpoints
    class DeleteJournalEntry < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

      def handle(id:)
        case delete_journal_entry.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("journal entry", id))
          else failed("could not delete the journal entry")
        end
      end
    end
  end
end
