# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Services < Action
        include Deps["operations.build_services_page"]

        before :allow_oauth_redirects

        def handle(request, response)
          services = { connect: request.params[:connect], selected: request.params[:selected] }
          tokens = { minted: request.flash[UI::Components::Tokens::List::MINTED] }

          response.render(view, **build_services_page.call(services:, tokens:))
        end
      end
    end
  end
end
