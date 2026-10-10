# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Create < Action
        MINTED = "tokens_page.toasts.minted"

        include Deps[
          index_view: "ui.views.tokens.index",
          api_token_queries: "api.repos.api_token_queries",
          mint_token: "api.operations.mint_token",
        ]

        def handle(request, response)
          params = minting(Blog::Types::Fields[request.params[:token]])

          case mint_token.call(params)
            in Success({ value: })
              minted(response, value)
            in Failure[:invalid, errors]
              invalid(response, params, errors)
            else halt 500
          end
        end

        private

        def invalid(response, params, errors)
          response.status = 422
          response.render(
            index_view,
            errors:, minted: nil, tokens: api_token_queries.live, name: params[:name].to_s,
            scopes: Array(params[:scopes]), expires_on: params[:expires_on].to_s,
          )
        end

        def minted(response, value)
          response.flash[UI::Views::Tokens::Index::MINTED] = value
          toast(response, MINTED)
          response.redirect_to(routes.path(:admin_tokens))
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
