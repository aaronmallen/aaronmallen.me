# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class MemoryEndpoint < Endpoint
      CHANGED = "the fact changed since, in history entry %s; revert that entry first"
      REMOVED = "the fact was removed; revert its removal first"
      UNREVERTIBLE = "only an add, an edit or a remove can be reverted"

      private

      def settled(result, id, missing: Helpers::Wording.missing("memory file", id))
        case result
          in Success(value) then Success(yield(value))
          in Failure(:not_found) then not_found(missing)
          in Failure(:removed) then invalid(fact_id: [REMOVED])
          in Failure(:unrevertible) then invalid(event_id: [UNREVERTIBLE])
          in Failure[:changed, later] then invalid(event_id: [format(CHANGED, later)])
          in Failure[:invalid, errors] then rejected(errors, Memory::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
