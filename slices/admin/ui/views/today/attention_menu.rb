# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class AttentionMenu < View
          BROKEN_LINK = Blog::Types::AttentionKind["broken_link"]
          CARRIED = Blog::Types::AttentionKind["carried"]
          DRAFT = Blog::Types::AttentionKind["draft"]
          JOURNAL = Blog::Types::AttentionKind["journal"]
          JOURNAL_ICON = "fa-solid #{Blog::Helpers::RecordKinds.icon('journal_entry')}".freeze
          LAPSING = Blog::Types::AttentionKind["lapsing"]
          NEW_DEVICE = Blog::Types::AttentionKind["new_device"]
          NEXT = Blog::Types::TaskFilter["next"]
          ORIGIN = Blog::Types::TaskOrigin["today"]
          SOMEDAY = Blog::Types::AttentionKind["someday"]

          layout nil

          prop :row, Blog::Types::Instance(Data)

          def view_template
            ContextMenu(label: journal? ? t(".journal") : @row.title) do |menu|
              opens(menu)
              task(menu) if [CARRIED, SOMEDAY].include?(@row.kind)
              snooze(menu)
            end
          end

          private

          def journal? = @row.kind == JOURNAL

          def opener(menu, href, label = t(".open")) = menu.link(label, href:, icon: "fa-regular fa-folder-open")

          def opens(menu)
            case @row.kind
              when CARRIED, SOMEDAY then opener(menu, path(:admin_task, id: @row.record_id, origin: ORIGIN))
              when DRAFT then opener(menu, path(:admin_edit_post, id: @row.record_id))
              when BROKEN_LINK then opener(menu, path(:admin_edit_post, id: @row.post_id))
              when JOURNAL then write(menu)
              when NEW_DEVICE then opener(menu, path(:admin_security), t(".open_security"))
              when LAPSING then services(menu)
            end
          end

          def services(menu) = opener(menu, path(:admin_services, selected: @row.record_id), t(".open_services"))

          def snooze(menu)
            fields = { kind: @row.kind, record_id: @row.record_id }.compact

            menu.separator
            menu.post(t(".snooze"), action: path(:admin_snooze_attention), fields:, icon: "fa-solid fa-bell-slash")
          end

          def task(menu)
            id = @row.record_id
            list = t(Helpers::TaskLists.title(NEXT))
            move = path(:admin_move_task, id:, filter: NEXT)
            cancel = path(:admin_cancel_task, id:)
            fields = { origin: ORIGIN }

            menu.post(t(".move", list:), action: move, fields:, icon: "fa-solid fa-arrow-right")
            menu.post(t(".cancel"), action: cancel, fields:, icon: :ban, warn: true,
                                    confirm: t(".confirm_cancel"))
          end

          def write(menu)
            href = path(:admin_journal, write: Blog::Constants::CHECKED)

            menu.link(t(".write"), href:, icon: JOURNAL_ICON, dialog: Components::Journal::WriteDialog::ID)
          end
        end
      end
    end
  end
end
