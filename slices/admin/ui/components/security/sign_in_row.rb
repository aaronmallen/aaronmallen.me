# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SignInRow < Component
          include Located

          OUTCOMES = Blog::Types::SignInOutcome.values.to_h { [it, ".outcomes.#{it}"] }.freeze
          PROVIDERS = Views::Sessions::Failed::NAMES.transform_keys(&:to_s).freeze
          SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

          prop :sign_in, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device(@sign_in)) do |item|
              item.meta do
                p(class: "li-sub") { dotted(provider, place(@sign_in), @sign_in.address) }
                p(class: "li-sub") { Moment(at: @sign_in.created_at) }
              end
              outcome
            end
          end

          private

          def dismiss_form
            ButtonForm(
              action: path(:admin_dismiss_sign_in, id: @sign_in.id), label: t(".dismiss"), variant: :gh, icon: :close,
              icon_only: true,
            )
          end

          def outcome
            Pill(color: signed_in? ? :green : :pink) { t(OUTCOMES.fetch(@sign_in.outcome), name: provider) }
            dismiss_form unless signed_in?
          end

          def provider = PROVIDERS.fetch(@sign_in.provider)

          def signed_in? = @sign_in.outcome == SIGNED_IN
        end
      end
    end
  end
end
