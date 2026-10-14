# frozen_string_literal: true

module API
  module Endpoints
    class CreateTag < TagEndpoint
      SCHEMA = { additionalProperties: false, properties: PROPERTIES, required: ["scope"] }.freeze

      include Deps[save_tag: "tags.operations.save_tag"]

      def handle(scope:, name: nil, color: nil) = saved(save_tag.call({ name:, color: }, scope:))
    end
  end
end
