# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectEditor
      FIELDS = %i[board_published key name og_image_url repo started_on tagline url visibility].freeze
      MONTH_FORMAT = "%Y-%m"
      OPTIONAL = %i[og_image_url repo tagline url].freeze
      PUBLIC = Blog::Types::TagScope["public"]

      include Deps[tag_queries: "tags.repos.tag_queries"]

      def call(project: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? from_params(params) : from_project(project)

        { project:, values:, errors:, tags: tag_queries.all_in(PUBLIC) }
      end

      private

      def blank_values = (FIELDS + [:tags]).to_h { [it, Blog::Constants::EMPTY_STRING] }

      def from_params(params) = (FIELDS + [:tags]).to_h { [it, Blog::Types::Text[params[it]]] }

      def from_project(project)
        return blank_values unless project

        {
          board_published: project.board_published ? Blog::Constants::CHECKED : Blog::Constants::UNCHECKED,
          key: project.key,
          name: project.name,
          visibility: project.visibility,
          started_on: started_on(project),
          tags: Blog::Types::TagField[project.tags],
          **OPTIONAL.to_h { [it, project.public_send(it).to_s] },
        }
      end

      def started_on(project)
        return Blog::Constants::EMPTY_STRING unless project.started_on

        project.started_on.strftime(MONTH_FORMAT)
      end
    end
  end
end
