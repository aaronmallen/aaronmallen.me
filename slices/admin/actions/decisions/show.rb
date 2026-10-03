# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Show < Action
        include Deps[decision_by_id: "decisions.queries.by_id"]

        def handle(request, response)
          decision = decision_by_id.call(record_id(request))
          not_found(response) unless decision

          response.render(view, decision:, form: Blog::Constants::EMPTY_HASH)
        end
      end
    end
  end
end
