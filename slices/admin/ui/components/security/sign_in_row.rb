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
              Pill(color: @sign_in.outcome == SIGNED_IN ? :green : :pink) do
                t(OUTCOMES.fetch(@sign_in.outcome), name: provider)
              end
            end
          end

          private

          def provider = PROVIDERS.fetch(@sign_in.provider)
        end
      end
    end
  end
end
