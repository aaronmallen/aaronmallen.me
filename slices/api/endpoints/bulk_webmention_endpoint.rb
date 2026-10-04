# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkWebmentionEndpoint < Endpoint
      REPLY = Schema.object({ webmentions: Schema.list(Serializers::Webmention.reference) }).freeze
      SCHEMA = Webmentions::BULK
      UNCHANGED = "could not change webmention %s"

      include Deps[act_on_webmentions: "social.operations.act_on_webmentions"]

      def handle(ids:)
        case act_on_webmentions.call({ act: self.class::ACT, ids: })
        in Success[*mentions] then Success(webmentions: serialized(Serializers::Webmention, mentions))
        in Failure[:record, id, :not_found] then invalid(ids: [Webmentions.missing(id)])
        in Failure[:record, id, _] then failed(format(UNCHANGED, id))
        in Failure[:invalid, errors] then invalid(errors)
        else failed(Webmentions::UNSAVED)
        end
      end
    end
  end
end
