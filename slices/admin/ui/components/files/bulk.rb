# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class Bulk < Component
          ADD = "add"
          GROUP = "group"
          ID = "files-bulk"

          prop :groups, Blog::Types::Hash

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_files), label: t(".label"), toggled: true) do |bar|
              bar.act(GROUP, icon: GroupTile::GROUP_ICON, label: t(".group"))
              next if @groups.empty?

              bar.choose(
                "group_id", ADD,
                prompt: t(".pick_group"), options: @groups, icon: "fa-solid fa-plus", label: t(".add"),
              )
            end
          end
        end
      end
    end
  end
end
