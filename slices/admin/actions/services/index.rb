# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Index < Action
        def handle(request, response)
          params = request.params.to_h.slice(:connect, :selected).compact

          response.redirect_to(Helpers::ServiceTab.services(routes, **params))
        end
      end
    end
  end
end
