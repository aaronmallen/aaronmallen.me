# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Edit < Action
        include Deps[share_queries: "shares.repos.share_queries"]

        def handle(request, response)
          share = share_queries.find(record_id(request))
          not_found(response) unless share

          response.render(view, share:)
        end
      end
    end
  end
end
