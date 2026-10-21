# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class MemoryEndpoint < Endpoint
      CHANGED = "it changed since, in history entry %s; revert that entry first"
      REMOVED = "the fact was removed; revert its removal first"
      UNREVERTIBLE = "only an add, an edit, a remove or a describe can be reverted"
      REFUSALS = { removed: { fact_id: [REMOVED] }, unrevertible: { event_id: [UNREVERTIBLE] } }.freeze

      include Deps[record_loads: "agents.operations.record_loads"]

      private

      def read_by(session_id, memory_file_ids)
        case record_loads.call(session_id, memory_file_ids)
          in Success then Success(yield)
          in Failure[:invalid, errors] then rejected(errors, Memory::COMPLAINTS)
        end
      end

      def settled(result, id, missing: Helpers::Wording.missing("memory file", id))
        case result
          in Success(value) then Success(yield(value))
          in Failure(:not_found) then not_found(missing)
          in Failure(:removed | :unrevertible => reason) then invalid(REFUSALS.fetch(reason))
          in Failure[:changed, later] then invalid(event_id: [format(CHANGED, later)])
          in Failure[:invalid, errors] then rejected(errors, Memory::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
