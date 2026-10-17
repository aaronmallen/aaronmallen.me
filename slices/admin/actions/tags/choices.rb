# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Tags
      class Choices < Action
        PRIVATE = Blog::Types::TagScope["private"]

        include Deps[tag_queries: "tags.repos.tag_queries"]

        config.formats.accept :json

        def handle(_request, response)
          response.format = :json
          response.body = JSON.generate(tags: UI::Components::TagField.choices(tag_queries.all_in(PRIVATE,
                                                                                                  mail: false)))
        end

        private

        def require_sign_in(request, _response)
          halt :unauthorized unless auth_session(request).signed_in?
        end
      end
    end
  end
end
