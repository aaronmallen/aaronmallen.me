# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module TaskRules
      ID = Helpers::Schema::ID
      UNSAVED = "could not save the rule"

      COMPLAINTS = {
        pattern: {
          Blog::Contract::BLANK => "name a repo or team first",
          Blog::Contract::FORMAT => "name one repo or team as owner/name, or all of an owner's as owner/*",
          "taken" => "another rule already holds that pattern",
        },
        projects: {
          Blog::Contract::FORMAT => "a project is named by its ID",
          "missing" => "no project has one of those IDs",
        },
        tags: {
          Blog::Contract::BLANK => "name a tag or a project first",
          Blog::Contract::FORMAT => Helpers::Tags::REFUSAL,
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

      PROJECTS = {
        type: "array",
        items: ID,
        description: "the IDs of the projects the rule links each issue to; a private or archived one is fine",
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "the private tags the rule gives, #{Helpers::Tags::FORMAT}; a new one is made",
      }.freeze
    end
  end
end
