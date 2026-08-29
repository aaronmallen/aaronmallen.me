# frozen_string_literal: true

module Admin
  module Actions
    module Analytics
      class Show < Action
        include Deps[summarize_analytics: "operations.summarize_analytics"]

        def handle(request, response)
          range = Blog::Types::AnalyticsRangeParam[request.params[:range]]

          response.render(view, **summarize_analytics.call(range:))
        end
      end
    end
  end
end
