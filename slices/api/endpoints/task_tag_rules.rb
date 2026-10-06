# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module TaskTagRules
      ID = Schema::ID
      UNSAVED = "could not save the rule"

      COMPLAINTS = {
        pattern: {
          Blog::Contract::BLANK => "name a repo or team first",
          Blog::Contract::FORMAT => "name one repo or team as owner/name, or all of an owner's as owner/*",
          "taken" => "another rule already holds that pattern",
        },
        tags: {
          Blog::Contract::BLANK => "name a tag first",
          Blog::Contract::FORMAT => "a tag is lowercase words joined by hyphens",
        },
      }.freeze

      PATTERN = {
        type: "string",
        description: [
          "for GitHub, one repo as owner/name or every repo of an owner as owner/*;",
          "for Linear, one team as workspace/team or every team of a workspace as workspace/*;",
          "case does not matter",
        ].join(" "),
      }.freeze

      PROVIDER = {
        type: "string",
        enum: Blog::Types::TaskSourceProvider.values,
        description: "where the issues the rule matches come from",
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "the private tags the rule gives, lowercase words joined by hyphens; a new one is made",
      }.freeze

      module_function

      def missing(id) = "no task tag rule has the ID #{id}"
    end
  end
end
