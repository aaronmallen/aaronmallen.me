# frozen_string_literal: true

module MCP
  module Tools
    class SaveProject < Base
      FIELDS = %i[featured name og_image_url repo started_on status tagline tags url].freeze
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
        status: { "format" => "pick a status from the list" },
        tags: { "format" => "use lowercase letters, numbers and single dashes in each tag" },
        url: { "format" => "enter a link that starts with http:// or https://" },
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          featured: { type: "boolean", description: "whether /projects shows it first" },
          id: API::Schema::ID.merge(description: "the project to change; leave it out to add a new one"),
          name: { type: "string" },
          og_image_url: { type: "string", description: "a link to the social card image" },
          repo: { type: "string", description: "the GitHub repository, as owner/repo" },
          started_on: { type: "string", description: "the month it started, as YYYY-MM" },
          status: { type: "string", enum: Blog::Types::ProjectLiveStatus.values },
          tagline: { type: "string" },
          tags: { type: "array", items: { type: "string" }, description: "every tag it carries, in place of those" },
          url: { type: "string", description: "its home page; a repository alone links to GitHub" },
        },
      }.freeze

      description "Add a project, or change one when you give its id. On a change, a field you leave out keeps " \
                  "what it has and an empty string clears it; tags replaces the whole list. A new project needs " \
                  "a name and starts active unless you give a status. An archived project keeps its status: " \
                  "restore it with restore_project"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, id: nil, **fields)
          current = id && dep(:project_by_id, server_context).call(id)
          return refuse(API::Wording.missing("project", id)) if id && current.nil?

          saved(dep(:save_project, server_context).call(form(current, fields), id:), id)
        end

        private

        def form(current, fields)
          given = kept(current).merge(fields.slice(*FIELDS))

          given.merge(featured: given[:featured] ? Blog::Constants::CHECKED : nil, tags: Array(given[:tags]).join(","))
        end

        def kept(project)
          return Blog::Constants::EMPTY_HASH unless project

          {
            featured: project.featured,
            name: project.name,
            og_image_url: project.og_image_url,
            repo: project.repo,
            started_on: project.started_on&.strftime(MONTH),
            status: project.archived? ? nil : project.status,
            tagline: project.tagline,
            tags: project.tags.map(&:name),
            url: project.url,
          }
        end

        def saved(result, id)
          case result
          in Success(project) then answer(ListProjects.summary(project))
          in Failure[:invalid, errors] then refuse(Complaints.call(errors, MESSAGES))
          in Failure(:not_found) then refuse(API::Wording.missing("project", id))
          else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
