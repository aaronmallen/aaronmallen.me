# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Menu < Action
        include Deps[share_queries: "shares.repos.share_queries"]

        def handle(request, response)
          share = share_queries.find(record_id(request)) || halt(404)
          return_to = auth_session(request).admin_return_path(request.params[:return_to])

          response.render(view, share:, return_to:)
        end
      end
    end
  end
end
