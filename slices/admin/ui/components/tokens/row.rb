# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Row < Component
          SEPARATOR = " · "

          prop :token, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @token.name, sub:) { revoke_form }
          end

          private

          def last_used
            return t(".never_used") if @token.last_used_at.nil?

            t(".last_used", time: stamp(@token.last_used_at))
          end

          def minted = t(".minted", time: stamp(@token.created_at))

          def revoke_attributes
            {
              action: path(:admin_revoke_token, id: @token.id),
              data: { confirm: t(".confirm_revoke", token: @token.name) },
            }
          end

          def revoke_form
            Form(**revoke_attributes) do
              Button(variant: :warn, small: true, type: "submit") { t(".revoke") }
            end
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)

          def sub = [minted, last_used].join(SEPARATOR)
        end
      end
    end
  end
end
