# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Create < Action
        MINTED = "tokens_page.toasts.minted"

        include Deps[
          "operations.build_services_page",
          mint_token: "api.operations.mint_token",
          services_view: "ui.views.settings.services",
        ]

        def handle(request, response)
          params = minting(Blog::Types::Fields[request.params[:token]])

          case mint_token.call(params)
            in Success({ value: })
              minted(response, value)
            in Failure[:invalid, errors]
              invalid(response, params, errors)
          end
        end

        private

        def invalid(response, params, errors)
          tokens = {
            errors:, name: params[:name].to_s, scopes: Array(params[:scopes]), expires_on: params[:expires_on].to_s,
          }
          unprocessable(response, services_view, **build_services_page.call(tokens:))
        end

        def minted(response, value)
          response.flash[UI::Components::Tokens::List::MINTED] = value
          toast(response, MINTED)
          response.redirect_to(Helpers::ServiceTab.tokens(routes))
        end

        def minting(params)
          scopes = params[:scopes]
          return params unless scopes.is_a?(Hash)

          params.merge(scopes: scopes.select { |_, value| value == Blog::Constants::CHECKED }.keys.map(&:to_s))
        end
      end
    end
  end
end
