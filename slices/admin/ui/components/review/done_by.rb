# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DoneBy < Component
          ANYONE = Blog::Constants::EMPTY_STRING
          ME = Operations::BuildReviewPage::ME

          prop :by, Blog::Types::String.optional
          prop :agents, Blog::Types::Array.of(Blog::Types::String)
          prop :keep, Blog::Types::Hash

          def view_template
            AutoForm(action: path(:admin_review), class: "review-by") do
              HiddenFields(values: @keep)
              Select(name: "by", options:, selected: @by || ANYONE, aria: { label: t(".label") }, class: "w-auto")
            end
          end

          private

          def options
            { ANYONE => t(".anyone"), ME => t(".me"), **[*@agents, @by].compact.uniq.-([ME]).to_h { [it, it] } }
          end
        end
      end
    end
  end
end
