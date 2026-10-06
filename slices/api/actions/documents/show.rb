# frozen_string_literal: true

module API
  module Actions
    module Documents
      class Show < Action
        SCHEMA = { additionalProperties: false }.freeze
        REPLY = { type: "object", description: "this OpenAPI document" }.freeze

        include Deps[document: "operations.build_document"]

        def handle(_request, response) = render_json(response, document.call)
      end
    end
  end
end
