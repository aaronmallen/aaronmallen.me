# frozen_string_literal: true

module Admin
  module Actions
    module Health
      class Show < Action
        SCOPE = Blog::Types::OAuthScope["health"]

        include Deps[
          api_token_queries: "api.repos.api_token_queries", client_queries: "api.repos.client_queries",
          health_queries: "health.repos.health_queries",
        ]

        def handle(request, response)
          params = request.params
          today = Blog::TimeZone.today
          span = Blog::Types::HealthSpanParam[params[:span]]
          from = today - span + 1

          response.render(
            view,
            report: health_queries.report(from:, to: today), day: day(params[:day], from..today), span:, today:,
            clients: client_queries.holding(SCOPE), tokens:,
          )
        end

        private

        def day(param, range) = Blog::Types::DateParam[param].then { range.cover?(it) ? it : range.end }

        def tokens = api_token_queries.live.select { it.scopes.include?(SCOPE) }
      end
    end
  end
end
