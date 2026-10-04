# frozen_string_literal: true

module Admin
  module Actions
    module TimeReport
      class Show < Action
        include Deps[build_time_page: "operations.build_time_page"]

        def handle(request, response)
          params = request.params

          response.render(view, **build_time_page.call(from: params[:from], to: params[:to], by: params[:by]))
        end
      end
    end
  end
end
