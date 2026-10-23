# frozen_string_literal: true

module API
  module Helpers
    module Tags
      FORMAT = "lowercase words joined by hyphens"
      LINKED = [
        "a record linked to a project takes the tags of its projects in place of private ones,",
        "and a name none of them holds is made in each",
      ].join(" ").freeze
      REFUSAL = "a tag is #{FORMAT}".freeze
      COMPLAINTS = { "blank" => "name the tag first", Blog::Contract::FORMAT => REFUSAL }.freeze

      module_function

      def filter(tag) = tag.to_s.strip.downcase.then { it unless it.empty? }

      def schema(scope) = { type: "string", description: "one #{scope} tag, #{FORMAT}" }.freeze
    end
  end
end
