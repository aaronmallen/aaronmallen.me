# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Tasks
      class Palette < Action
        UNAUTHORIZED = 401

        include Deps[open_tasks: "tasks.queries.open_tasks"]

        config.formats.accept :json

        before :forbid_caching

        def handle(_request, response)
          response.format = :json
          response.body = JSON.generate(tasks:)
        end

        private

        def require_sign_in(request, _response)
          halt UNAUTHORIZED unless auth_session(request).signed_in?
        end

        def tasks
          open_tasks.call.flat_map do |list, found|
            found.map { { id: it.id, title: it.title, list: } }
          end
        end
      end
    end
  end
end
