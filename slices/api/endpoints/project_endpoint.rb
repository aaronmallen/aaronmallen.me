# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class ProjectEndpoint < Endpoint
      ABOUT_KEY = "2 to 6 letters and digits that start with a letter, as POD; its tasks show as KEY-n. Empty, " \
                  "or left out of a new project, it takes the first 3 letters of the name"
      FIELDS = %i[board_published key name og_image_url repo started_on tagline tags url visibility].freeze
      LINK = "enter a link that starts with http:// or https://"
      MONTH = "%Y-%m"
      PUBLIC = Blog::Types::ProjectVisibility["public"]
      UNCHECKED = "0"
      UNSAVED = "could not save the project"

      COMPLAINTS = {
        key: {
          Blog::Contract::FORMAT => "use 2 to 6 letters and digits that start with a letter, as POD",
          "taken" => "another project already has this key",
        },
        name: { Blog::Contract::BLANK => "add a name" },
        og_image_url: { Blog::Contract::FORMAT => LINK },
        repo: {
          Blog::Contract::FORMAT => "name the repository as owner/repo, as octocat/hello-world",
          "taken" => "another project already tracks this repository",
        },
        started_on: {
          "after_archived" => "the start month falls after the day this project was archived",
          Blog::Contract::FORMAT => "use the year and the month, as 2024-06",
          "future" => "pick this month or one before it",
        },
        tags: { Blog::Contract::FORMAT => Helpers::Tags::REFUSAL },
        url: { Blog::Contract::FORMAT => LINK },
        visibility: { Blog::Contract::BLANK => "pick public or private",
                      Blog::Contract::FORMAT => "pick public or private" },
      }.freeze

      PROPERTIES = {
        board_published: { type: "boolean", description: "whether a public project shows its task board" },
        key: { type: "string", description: ABOUT_KEY },
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
      }.freeze

      REPLY = Serializers::Project.reference

      include Deps[
        link_repo_tasks: "tasks.operations.link_repo_tasks",
        project_queries: "projects.repos.project_queries",
        save_project: "projects.operations.save_project",
      ]

      private

      def answered(id) = Success(serialized(Serializers::Project, project_queries.by_id(id)))

      def form(current, fields)
        given = kept(current).merge(fields.slice(*FIELDS))

        given.merge(
          board_published: given[:board_published] ? Blog::Constants::CHECKED : UNCHECKED,
          tags: Helpers::Wording.tag_list(given[:tags]),
        )
      end

      def kept(project)
        return Blog::Constants::EMPTY_HASH unless project

        {
          board_published: project.board_published,
          key: project.key,
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

      def public_in(fields)
        current = project_queries.by_id(fields[:id]) if fields.key?(:id)
        return if fields.key?(:id) && current.nil?

        "this project" if fields.fetch(:visibility) { current&.visibility } == PUBLIC
      end

      def saved(fields, current: nil)
        id = current&.id
        result = save_project.call(form(current, fields), id:).fmap { link_repo_tasks.call(it, was: current&.repo) }

        case result
          in Success(project) then Success(serialized(Serializers::Project, project))
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in Failure(:not_found) then missing("project", id)
          else failed(UNSAVED)
        end
      end
    end
  end
end
