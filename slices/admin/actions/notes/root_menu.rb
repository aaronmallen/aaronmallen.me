# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class RootMenu < Action
        def handle(request, response) = response.render(view, return_to: back_here(request))
      end
    end
  end
end
