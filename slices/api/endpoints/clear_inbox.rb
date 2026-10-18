# frozen_string_literal: true

module API
  module Endpoints
    class ClearInbox < Endpoint
      EMPTY = "name at least one row to clear"
      IDS = Helpers::Schema.list(Helpers::Schema::ID).freeze
      NOUNS = { tasks: "task", messages: "message", webmentions: "webmention" }.freeze
      SCOPED = true
      UNCHANGED = "could not clear %s %s"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          tasks: IDS.merge(description: "the ids of task rows from list_inbox to mark seen"),
          messages: IDS.merge(
            description: "the ids of message rows from list_inbox to mark read; needs the mail scope",
          ),
          webmentions: IDS.merge(description: "the ids of webmention rows from list_inbox to mark seen, left pending"),
        },
      }.freeze

      REPLY = Helpers::Schema.object(NOUNS.transform_values { IDS }).freeze

      include Deps[clear_inbox: "operations.clear_inbox"]

      def handle(scopes:, **ids) = refuse_mail(:messages, ids[:messages]&.any?, scopes) || cleared(ids)

      private

      def cleared(ids)
        case clear_inbox.call(ids)
          in Success => cleared then cleared
          in Failure[:record, kind, id, reason] then invalid(kind => [refused(NOUNS.fetch(kind), id, reason)])
          in Failure[:invalid, _] then invalid(input: [EMPTY])
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end

      def refused(noun, id, reason)
        reason == :not_found ? Helpers::Wording.missing(noun, id) : format(UNCHANGED, noun, id)
      end
    end
  end
end
