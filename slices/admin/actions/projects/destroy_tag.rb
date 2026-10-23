# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class DestroyTag < ProjectTagAction
        include Deps[remove_tag: "tags.operations.remove_tag"]

        def handle(request, response)
          result = remove_tag.call(record_id(request, :tag_id), scope: PROJECT, project_id: project_id(request))

          settled(request, response, result, "removed")
        end
      end
    end
  end
end
