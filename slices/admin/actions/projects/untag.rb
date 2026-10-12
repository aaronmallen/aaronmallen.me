# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Untag < TagAction
        DONE = "untagged"

        include Deps[untag_project: "projects.operations.untag_project"]

        private

        def list_path = routes.path(:admin_projects)

        def retag(id, tag) = untag_project.call(id, tag)
      end
    end
  end
end
