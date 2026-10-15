# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Index < Action
        PAGE_SIZE = 12

        include Deps[
          share_group_queries: "shares.repos.share_group_queries", share_queries: "shares.repos.share_queries",
        ]

        def handle(request, response)
          list = listed(request.params)
          page = requested_page(request, response)
          shares = share_queries.page_listed(page, **list)
          not_found(response) if shares.past_end?

          list_groups(response, list, page)
          response[:list] = list
          response[:shares] = shares
          response[:totals] = share_queries.totals.merge(groups: share_group_queries.count)
        end

        private

        def list_groups(response, list, page)
          groups = share_group_queries.listed(**list)

          response[:count] = share_queries.count_listed(**list) + groups.size
          response[:groups] = page.number == 1 ? groups : []
          response[:group_options] = share_group_queries.options
        end

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
