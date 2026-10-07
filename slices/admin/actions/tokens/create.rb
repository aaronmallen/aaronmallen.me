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
          params = Blog::Types::Fields[request.params[:token]]

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
            errors:, minted: nil, name: params[:name].to_s, tokens: api_token_queries.live,
          )
        end

        def minted(response, value)
          response.flash[UI::Views::Tokens::Index::MINTED] = value
          toast(response, MINTED)
          response.redirect_to(routes.path(:admin_tokens))
        end
      end
    end
  end
end
