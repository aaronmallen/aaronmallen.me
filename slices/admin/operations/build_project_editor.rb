# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectEditor
      FIELDS = %i[name og_image_url repo started_on status tagline url].freeze
      MONTH_FORMAT = "%Y-%m"
      OPTIONAL = %i[og_image_url repo tagline url].freeze
      TAG_SEPARATOR = ", "

      def call(project: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? from_params(params) : from_project(project)

        {
          project:,
          values:,
          featured: featured(project, params),
          errors:,
        }
      end

      private

      def blank_values
        FIELDS.to_h { [it, Blog::Constants::EMPTY_STRING] }
              .merge(status: Blog::Types::ProjectLiveStatus["active"], tags: Blog::Constants::EMPTY_STRING)
      end

      def featured(project, params)
        return Blog::Types::Checkbox[params[:featured]] if params

        project ? project.featured : false
      end

      def from_params(params) = (FIELDS + [:tags]).to_h { [it, Blog::Types::Text[params[it]]] }

      def from_project(project)
        return blank_values unless project

        {
          name: project.name,
          status: project.status,
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
