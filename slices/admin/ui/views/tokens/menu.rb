# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tokens
        class Menu < View
          layout nil

          prop :token, Blog::Types::Instance(ROM::Struct)

          def view_template
            ContextMenu(label: @token.name) do |menu|
              menu.post(t(".revoke"), action: path(:admin_revoke_token, id: @token.id), icon: :ban,
                                      warn: true, confirm: :revoke)
            end
          end
        end
      end
    end
  end
end
