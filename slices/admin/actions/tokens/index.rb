# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Index < Action
        include Deps[api_token_queries: "api.repos.api_token_queries"]

        def handle(request, response)
          response.render(
            view,
            errors: Blog::Constants::EMPTY_HASH,
            minted: request.flash[UI::Views::Tokens::Index::MINTED],
            name: Blog::Constants::EMPTY_STRING,
            tokens: api_token_queries.live,
          )
        end
      end
    end
  end
end
