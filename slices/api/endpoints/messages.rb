# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Messages
      MOST_IDS = 100
      IDS = {
        type: "array",
        items: Schema::ID,
        minItems: 1,
        maxItems: MOST_IDS,
        description: "the messages to change, #{MOST_IDS} at most; one that fails changes none".freeze,
      }.freeze
      BULK = { additionalProperties: false, properties: { ids: IDS }, required: ["ids"] }.freeze
      UNCHANGED = "could not change message %s"
      UNSAVED = "could not save the change"

      module_function

      def missing(id) = "no message has the ID #{id}"
    end
  end
end
