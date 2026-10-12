# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Tag < TagAction
        DONE = "tagged"

        include Deps[tag_project: "projects.operations.tag_project"]

        private

        def list_path = routes.path(:admin_projects)

        def retag(id, tag) = tag_project.call(id, tag)
      end
    end
  end
end
