# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkEndpoint < Endpoint
      CONTRACTS = Blog::Constants::EMPTY_ARRAY
      COMPLAINTS = Blog::Constants::EMPTY_HASH
      REFUSALS = Blog::Constants::EMPTY_HASH
      UNCHANGED = "could not change %s %s"

      def handle(ids:) = acted(ids)

      private

      def acted(ids, **input)
        case act_on.call({ act: self.class::ACT, ids:, **input })
          in Success[*records] then Success(self.class::KEY => answered(records))
          in Failure[:record, id, reason] then refused(id, reason)
          in Failure[:invalid, errors] then rejected(keyed(errors), self.class::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end

      def keyed(errors) = errors.transform_values { it.is_a?(Hash) ? it.values.flatten.uniq : it }

      def refused(id, reason)
        return invalid(ids: [Helpers::Wording.missing(self.class::NOUN, id)]) if reason == :not_found
        return invalid(ids: [format(self.class::REFUSALS[reason], id)]) if self.class::REFUSALS.key?(reason)

        unhandled(reason, format(UNCHANGED, self.class::NOUN, id))
      end
    end
  end
end
