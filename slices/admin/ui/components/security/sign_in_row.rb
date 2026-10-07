# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SignInRow < Component
          OUTCOMES = %w[denied github_failed signed_in unexpected wrong_account].to_h { [it, ".outcomes.#{it}"] }.freeze

          prop :sign_in, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device) do |item|
              item.meta do
                p(class: "li-sub") do
                  Stamped(text: dotted(t(OUTCOMES.fetch(@sign_in.outcome)), Stamped::MARK), at: @sign_in.created_at)
                end
                p(class: "li-sub") { dotted(place, @sign_in.address) }
              end
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
