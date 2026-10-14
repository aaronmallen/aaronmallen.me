# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class EditGroup < Action
        include Deps[share_group_queries: "shares.repos.share_group_queries"]

        def handle(request, response)
          group = share_group_queries.find(record_id(request))
          not_found(response) unless group

          response.render(view, group:)
        end
      end
    end
  end
end
