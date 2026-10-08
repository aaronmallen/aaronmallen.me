# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SignInRow < Component
          OUTCOMES = %w[denied github_failed signed_in unexpected wrong_account].to_h { [it, ".outcomes.#{it}"] }.freeze

          SIGNED_IN = "signed_in"

          prop :sign_in, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device) do |item|
              item.meta do
                p(class: "li-sub") { dotted(place, @sign_in.address) }
                p(class: "li-sub") { Moment(at: @sign_in.created_at) }
              end
              Pill(color: @sign_in.outcome == SIGNED_IN ? :green : :pink) { t(OUTCOMES.fetch(@sign_in.outcome)) }
            end
          end

          private

          def device = dotted(@sign_in.browser, @sign_in.os).then { it.empty? ? t(".unknown_device") : it }

          def place = dotted(@sign_in.city, @sign_in.country).then { it.empty? ? t(".unknown_place") : it }
        end
      end
    end
  end
end
