# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class CreateTag < ProjectTagAction
        include Deps[save_tag: "tags.operations.save_tag"]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:tag]]
          result = save_tag.call(params, scope: PROJECT, project_id: project_id(request))

          settled(request, response, result, "added")
        end
      end
    end
  end
end
