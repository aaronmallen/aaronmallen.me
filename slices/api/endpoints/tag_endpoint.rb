# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TagEndpoint < Endpoint
      MAIL_TAG = "tag %s is on mail threads, so %s it needs the mail scope"
      PRIVATE_KINDS = "journal entries, tasks, decisions and task rules"
      PROJECT = Blog::Types::TagScope["project"]
      PROJECT_FIELD = {
        type: "string",
        description: "the key of the project that holds the tags, as POD; listing or adding them needs it",
      }.freeze
      SCOPE = {
        type: "string",
        enum: Blog::Types::TagScope.values,
        description: [
          "public holds the tags on posts and projects", "private holds those on #{PRIVATE_KINDS}",
          "project holds one project's own tags, named by its key in project",
        ].join("; "),
      }.freeze
      STRAY = "only the project scope takes a project"
      UNNAMED = "name the project that holds the tags"

      CONTRACTS = [::Tags::Contracts::TagContract].freeze
      COMPLAINTS = {
        color: { Blog::Contract::FORMAT => "pick one of the six colours" },
        name: {
          Blog::Contract::BLANK => "give the tag a name first",
          Blog::Contract::FORMAT => Helpers::Tags::REFUSAL,
          "taken" => "another tag already holds that name",
        },
      }.freeze

      PROPERTIES = {
        color: { type: "string", enum: Blog::Types::TagColor.values },
        description: {
          type: "string",
          description: "what the tag covers, in markdown; a public tag's page shows it. An empty string clears it",
        },
        name: { type: "string", description: Helpers::Tags::FORMAT },
        project: PROJECT_FIELD,
        scope: SCOPE,
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          color: Helpers::Schema::STRING,
          description: Helpers::Schema.nullable(Helpers::Schema::STRING),
        },
      ).freeze

      include Deps[project_queries: "projects.repos.project_queries"]

      private

      def project_id_for(scope, project)
        return project ? invalid(project: [STRAY]) : Success(nil) unless scope == PROJECT
        return invalid(project: [UNNAMED]) unless project

        id = project_queries.id_by_key(project.strip)
        id ? Success(id) : missing("project", project, by: "key")
      end

      def saved(result, id = nil)
        case result
          in Success(tag) then Success(id: tag.id, name: tag.name, color: tag.color, description: tag.description)
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in Failure(:not_found) then missing("tag", id)
          in unmatched then unhandled(unmatched, "could not save the tag")
        end
      end
    end
  end
end
