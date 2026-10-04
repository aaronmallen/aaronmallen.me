# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Webmentions
      MOST_IDS = 100
      IDS = {
        type: "array",
        items: { type: "integer" },
        minItems: 1,
        maxItems: MOST_IDS,
        description: "the webmentions to change, #{MOST_IDS} at most; one that fails changes none".freeze,
      }.freeze
      BULK = { additionalProperties: false, properties: { ids: IDS }, required: ["ids"] }.freeze
      UNSAVED = "could not save the change"

      module_function

      def missing(id) = "no webmention has the ID #{id}"
    end
  end
end
