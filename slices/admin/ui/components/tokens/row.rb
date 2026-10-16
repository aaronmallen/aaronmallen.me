# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Row < Component
          prop :token, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @token.name, data: { menu: path(:admin_token_menu, id: @token.id) }) do |item|
              item.meta { p(class: "li-sub") { sub } }
              revoke_form
            end
          end

          private

          def expiry
            return plain(t(".never_expires")) if @token.expires_at.nil?

            Stamped(text: t(".expires", time: Stamped::MARK), at: @token.expires_at)
          end

          def last_used
            return plain(t(".never_used")) if @token.last_used_at.nil?

            Stamped(text: t(".last_used", time: Stamped::MARK), at: @token.last_used_at)
          end

          def minted = Stamped(text: t(".minted", time: Stamped::MARK), at: @token.created_at)

          def revoke_form
            ButtonForm(
              action: path(:admin_revoke_token, id: @token.id), label: t(".revoke"), variant: :warn,
              confirm: t(".confirm_revoke", token: @token.name),
            )
          end

          def sub
            Dotted do |line|
              line.part { @token.scopes.join(", ") }
              line.part { minted }
              line.part { last_used }
              line.part { expiry }
            end
          end
        end
      end
    end
  end
end
