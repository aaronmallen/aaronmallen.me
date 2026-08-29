# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class SuggestionForms < Component
          ACCEPT = "post-suggestions-accept"
          REJECT = "post-suggestions-reject"

          prop :post_id, Blog::Types::Integer

          def view_template
            decision_form(ACCEPT, :admin_accept_post_suggestions)
            decision_form(REJECT, :admin_reject_post_suggestions)
          end

          private

          def decision_form(id, route)
            Form(id:, action: path(route, id: @post_id))
          end
        end
      end
    end
  end
end
