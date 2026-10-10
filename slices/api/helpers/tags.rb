# frozen_string_literal: true

module API
  module Helpers
    module Tags
      FORMAT = "lowercase words joined by hyphens"
      REFUSAL = "a tag is #{FORMAT}".freeze
      COMPLAINTS = { "blank" => "name the tag first", Blog::Contract::FORMAT => REFUSAL }.freeze

      module_function

      def schema(scope) = { type: "string", description: "one #{scope} tag, #{FORMAT}" }.freeze
    end
  end
end
