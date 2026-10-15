# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      module Redirect
        private

        def back_path(request) = back_here(request) || routes.path(:admin_projects, filter: filter(request))

        def filter(request) = Blog::Types::ProjectFilterParam[request.params[:filter]]
      end
    end
  end
end
