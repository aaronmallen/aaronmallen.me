# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Menu < Action
        include Deps[share_queries: "shares.repos.share_queries"]

        def handle(request, response)
          share = share_queries.find(record_id(request)) || halt(:not_found)

          response.render(view, share:, return_to: back_here(request))
        end
      end
    end
  end
end
