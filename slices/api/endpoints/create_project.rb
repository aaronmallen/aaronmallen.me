# frozen_string_literal: true

module API
  module Endpoints
    class CreateProject < ProjectEndpoint
      SCHEMA = { additionalProperties: false, properties: PROPERTIES }.freeze

      def handle(**fields) = saved(fields)
    end
  end
end
