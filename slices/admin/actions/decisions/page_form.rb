# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      module PageForm
        include Dry::Monads[:result]

        private

        def decision_params(request) = Blog::Types::Fields[request.params[:decision]]

        def refuse_form(request, response, form)
          decision = decision_by_id.call(record_id(request))
          halt 404 unless decision

          response.status = 422
          response.render(show_view, decision:, form:)
        end

        def to_decision(request, response, key)
          toast(response, key)
          response.redirect_to(routes.path(:admin_decision, id: record_id(request)))
        end
      end
    end
  end
end
