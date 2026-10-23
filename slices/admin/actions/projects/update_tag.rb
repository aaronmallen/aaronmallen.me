# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class UpdateTag < ProjectTagAction
        include Deps[save_tag: "tags.operations.save_tag"]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:tag]]
          id = record_id(request, :tag_id)
          result = save_tag.call(params, scope: PROJECT, id:, project_id: project_id(request))

          settled(request, response, result, "saved")
        end
      end
    end
  end
end
