# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Index < Action
        include Deps[live_tokens: "api.queries.live_tokens"]

        def handle(request, response)
          response.render(
            view,
            errors: Blog::Constants::EMPTY_HASH,
            minted: request.flash[UI::Views::Tokens::Index::MINTED],
            name: Blog::Constants::EMPTY_STRING,
            tokens: live_tokens.call,
          )
        end
      end
    end
  end
end
