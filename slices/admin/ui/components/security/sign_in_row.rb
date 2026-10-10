# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SignInRow < Component
          include Located

          OUTCOMES = %w[denied github_failed signed_in unexpected wrong_account].to_h { [it, ".outcomes.#{it}"] }.freeze

          SIGNED_IN = "signed_in"

          prop :sign_in, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device(@sign_in)) do |item|
              item.meta do
                p(class: "li-sub") { dotted(place(@sign_in), @sign_in.address) }
                p(class: "li-sub") { Moment(at: @sign_in.created_at) }
              end
              Pill(color: @sign_in.outcome == SIGNED_IN ? :green : :pink) { t(OUTCOMES.fetch(@sign_in.outcome)) }
            end
          end
        end
      end
    end
  end
end
