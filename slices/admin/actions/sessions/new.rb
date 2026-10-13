# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class New < Action
        before :allow_oauth_redirects

        def handle(_request, response) = response.render(view)

        private

        def sign_in_required? = false
      end
    end
  end
end
