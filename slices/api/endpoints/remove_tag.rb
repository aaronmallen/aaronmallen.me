# frozen_string_literal: true

module API
  module Endpoints
    class RemoveTag < TagEndpoint
      LAST_TAG = "tag %s is the only tag on %s %s"
      RULES = { true => "the task rule", false => "the task rules" }.freeze
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, scope: SCOPE },
        required: %w[id scope],
      }.freeze
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, removed: Helpers::Schema::BOOLEAN }).freeze

      include Deps[remove_tag: "tags.operations.remove_tag"]

      def handle(id:, scope:)
        case remove_tag.call(id, scope:)
          in Success(_) then Success(id:, removed: true)
          in Failure[:last_tag_of_rules, patterns]
            invalid(id: [format(LAST_TAG, id, RULES.fetch(patterns.one?), patterns.join(", "))])
          in Failure(:not_found) then missing("tag", id)
          else failed("could not remove the tag")
        end
      end
    end
  end
end
