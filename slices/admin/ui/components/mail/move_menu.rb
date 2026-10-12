# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class MoveMenu < Component
          ACT = Blog::Types::MessageBulkAction
          MOVES = {
            ACT["inbox"] => ["fa-solid fa-inbox", ".inbox"],
            ACT["archive"] => ["fa-solid fa-box-archive", ".archive"],
            ACT["spam"] => ["fa-solid fa-ban", ".spam"],
            ACT["trash"] => ["fa-regular fa-trash-can", ".trash"],
          }.freeze

          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :fields, Blog::Types::Hash
          prop :except, Blog::Types::String.optional

          def view_template
            @menu.sub(t(".move_to"), icon: "fa-solid fa-folder-open") do
              MOVES.except(@except).each do |act, (icon, key)|
                @menu.post(t(key), action: path(:admin_bulk_mail), icon:, fields: { **@fields, act: })
              end
            end
          end
        end
      end
    end
  end
end
