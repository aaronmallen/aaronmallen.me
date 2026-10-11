# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      module PageForm
        include Dry::Monads[:result]

        private

        def decision_params(request) = Blog::Types::Fields[request.params[:decision]]

        def decision_path(request) = routes.path(:admin_decision, id: record_id(request))

        def to_decision(request, response, key)
          toast(response, key)
          response.redirect_to(decision_path(request))
        end
      end
    end
  end
end
