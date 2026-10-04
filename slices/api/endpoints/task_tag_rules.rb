# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module TaskTagRules
      ID = Schema::ID
      UNSAVED = "could not save the rule"

      COMPLAINTS = {
        pattern: {
          Blog::Contract::BLANK => "name a repo first",
          Blog::Contract::FORMAT => "name one repo as owner/name, or every repo of an owner as owner/*",
          "taken" => "another rule already holds that pattern",
        },
        tags: {
          Blog::Contract::BLANK => "name a tag first",
          Blog::Contract::FORMAT => "a tag is lowercase words joined by hyphens",
        },
      }.freeze

      PATTERN = {
        type: "string",
        description: "one repo as owner/name, or every repo of an owner as owner/*; case does not matter",
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "the private tags the rule gives, lowercase words joined by hyphens; a new one is made",
      }.freeze

      module_function

      def complaints(errors)
        errors.to_h do |field, codes|
          [field, codes.map { COMPLAINTS.fetch(field, Blog::Constants::EMPTY_HASH).fetch(it, it) }]
        end
      end

      def missing(id) = "no task tag rule has the ID #{id}"
    end
  end
end
