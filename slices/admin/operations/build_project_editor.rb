# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectEditor
      FIELDS = %i[name og_image_url repo started_on tagline url visibility].freeze
      MONTH_FORMAT = "%Y-%m"
      OPTIONAL = %i[og_image_url repo tagline url].freeze
      TAG_SEPARATOR = ", "

      def call(project: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? from_params(params) : from_project(project)

        { project:, values:, errors: }
      end

      private

      def blank_values = (FIELDS + [:tags]).to_h { [it, Blog::Constants::EMPTY_STRING] }

      def from_params(params) = (FIELDS + [:tags]).to_h { [it, Blog::Types::Text[params[it]]] }

      def from_project(project)
        return blank_values unless project

        {
          name: project.name,
          visibility: project.visibility,
          started_on: started_on(project),
          tags: project.tags.map(&:name).join(TAG_SEPARATOR),
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
