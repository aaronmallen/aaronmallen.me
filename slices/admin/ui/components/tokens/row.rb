# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Row < Component
          prop :token, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @token.name) do |item|
              item.meta { p(class: "li-sub") { sub } }
              revoke_form
            end
          end

          private

          def expiry
            return plain(t(".never_expires")) if @token.expires_at.nil?

            stamped(".expires", @token.expires_at)
          end

          def last_used
            return plain(t(".never_used")) if @token.last_used_at.nil?

            stamped(".last_used", @token.last_used_at)
          end

          def minted = stamped(".minted", @token.created_at)

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

          def stamped(key, time)
            plain(t(key))
            whitespace
            Moment(at: time)
          end

          def sub
            plain(@token.scopes.join(", "))
            plain(DOT)
            minted
            plain(DOT)
            last_used
            plain(DOT)
            expiry
          end
        end
      end
    end
  end
end
