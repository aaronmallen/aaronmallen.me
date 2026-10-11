# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Index < Action
        PAGE_SIZE = 12

        include Deps[share_queries: "shares.repos.share_queries"]

        def handle(request, response)
          list = listed(request.params)
          shares = share_queries.page_listed(requested_page(request, response), **list)
          not_found(response) if shares.past_end?

          response[:count] = share_queries.count_listed(**list)
          response[:list] = list
          response[:shares] = shares
          response[:totals] = share_queries.totals
        end

        private

        def listed(params)
          {
            filter: Blog::Types::ShareFilterParam[params[:kind]],
            search: Blog::Types::OptionalText[params[:search]],
          }.compact
        end

        def page_size = PAGE_SIZE
      end
    end
  end
end
