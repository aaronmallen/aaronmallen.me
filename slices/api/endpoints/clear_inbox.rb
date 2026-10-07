# frozen_string_literal: true

module API
  module Endpoints
    class ClearInbox < Endpoint
      EMPTY = "name at least one row to clear"
      IDS = Schema.list(Schema::ID).freeze
      NOUNS = { tasks: "task", messages: "message", webmentions: "webmention" }.freeze
      UNCHANGED = "could not clear %s %s"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          tasks: IDS.merge(description: "the ids of task rows from list_inbox to mark seen"),
          messages: IDS.merge(description: "the ids of message rows from list_inbox to mark read"),
          webmentions: IDS.merge(description: "the ids of webmention rows from list_inbox to mark seen, left pending"),
        },
      }.freeze

      REPLY = Schema.object(NOUNS.transform_values { IDS }).freeze

      include Deps[clear_inbox: "operations.clear_inbox"]

      def handle(**ids)
        case clear_inbox.call(ids)
        in Success(cleared) then Success(cleared.transform_values { it.map(&:id) })
        in Failure[:record, kind, id, reason] then invalid(kind => [refused(NOUNS.fetch(kind), id, reason)])
        in Failure[:invalid, _] then invalid(input: [EMPTY])
        else failed(Wording::UNSAVED)
        end
      end

      private

      def refused(noun, id, reason) = reason == :not_found ? Wording.missing(noun, id) : format(UNCHANGED, noun, id)
    end
  end
end
