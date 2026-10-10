# frozen_string_literal: true

module API
  module Actions
    module Tokens
      class Show < Action
        SCHEMA = { additionalProperties: false }.freeze
        REPLY = Serializers::APIToken.reference

        def handle(_request, response)
          render_json(response, Serializers::APIToken.new(response[:token]).serializable_hash)
        end
      end
    end
  end
end
