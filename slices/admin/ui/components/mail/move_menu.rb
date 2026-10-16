# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class MoveMenu < Component
          ACT = Blog::Types::MessageBulkAction
          MOVES = %w[inbox archive spam trash].to_h { [ACT[it], ".#{it}"] }.freeze

          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :fields, Blog::Types::Hash
          prop :except, Blog::Types::String.optional

          def view_template
            @menu.sub(t(".move_to"), icon: "fa-solid fa-folder-open") do
              MOVES.except(@except).each do |act, key|
                fields = { **@fields, act: }
                @menu.post(t(key), action: path(:admin_bulk_mail), icon: ActIcon[act], fields:)
              end
            end
          end
        end
      end
    end
  end
end
