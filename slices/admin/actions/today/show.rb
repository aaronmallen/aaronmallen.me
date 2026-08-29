# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class Show < Action
        include Deps[summarize_today: "operations.summarize_today"]

        def handle(request, response)
          case summarize_today.call(pool: request.params[:pool])
          in Success(summary) then response.render(view, **summary)
          else halt 500
          end
        end
      end
    end
  end
end
