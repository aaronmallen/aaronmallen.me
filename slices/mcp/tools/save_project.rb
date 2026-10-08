# frozen_string_literal: true

module MCP
  module Tools
    class SaveProject < Base
      FIELDS = %i[name og_image_url repo started_on tagline tags url visibility].freeze
      MONTH = "%Y-%m"
      UNSAVED = "could not save the project"

      MESSAGES = {
        name: { "blank" => "add a name" },
        og_image_url: { "format" => "enter a link that starts with http:// or https://" },
        repo: {
          "format" => "name the repository as owner/repo, as octocat/hello-world",
          "taken" => "another project already tracks this repository",
        },
        started_on: {
          "after_archived" => "the start month falls after the day this project was archived",
          "format" => "use the year and the month, as 2024-06",
          "future" => "pick this month or one before it",
        },
        tags: { "format" => "use lowercase letters, numbers and single dashes in each tag" },
        url: { "format" => "enter a link that starts with http:// or https://" },
        visibility: { "blank" => "pick public or private", "format" => "pick public or private" },
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Helpers::Schema::ID.merge(description: "the project to change; leave it out to add a new one"),
          name: { type: "string" },
          og_image_url: { type: "string", description: "a link to the social card image" },
          repo: { type: "string", description: "the GitHub repository, as owner/repo" },
          started_on: { type: "string", description: "the month it started, as YYYY-MM" },
          tagline: { type: "string" },
          tags: { type: "array", items: { type: "string" }, description: "every tag it carries, in place of those" },
          url: { type: "string", description: "its home page; a repository alone links to GitHub" },
          visibility: {
            type: "string", enum: Blog::Types::ProjectVisibility.values,
            description: "who can see it; a private project stays off the site",
          },
        },
      }.freeze

      description "Add a project, or change one when you give its id. On a change, a field you leave out keeps " \
                  "what it has and an empty string clears it; tags replaces the whole list. A new project needs " \
                  "a name and a visibility, and starts active. Archive and restore it with archive_project and " \
                  "restore_project"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(server_context:, id: nil, **fields)
          current = id && dep(:project_queries, server_context).by_id(id)
          return refuse(API::Helpers::Wording.missing("project", id)) if id && current.nil?

          result = dep(:save_project, server_context).call(form(current, fields), id:)
          saved(result.bind { dep(:link_repo_tasks, server_context).call(it, was: current&.repo) }, id)
        end

        private

        def form(current, fields)
          given = kept(current).merge(fields.slice(*FIELDS))

          given.merge(tags: Array(given[:tags]).join(","))
        end

        def kept(project)
          return Blog::Constants::EMPTY_HASH unless project

          {
            name: project.name,
            og_image_url: project.og_image_url,
            repo: project.repo,
            started_on: project.started_on&.strftime(MONTH),
            tagline: project.tagline,
            tags: project.tags.map(&:name),
            url: project.url,
            visibility: project.visibility,
          }
        end

        def saved(result, id)
          case result
            in Success(project) then answer(ListProjects.summary(project))
            in Failure[:invalid, errors] then refuse(Complaints.call(errors, MESSAGES))
            in Failure(:not_found) then refuse(API::Helpers::Wording.missing("project", id))
            else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
