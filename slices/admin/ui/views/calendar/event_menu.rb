# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Calendar
        class EventMenu < View
          include Components::Calendar

          layout nil

          prop :event, Blog::Types::Instance(ROM::Struct)
          prop :day, Blog::Types::Date

          def view_template
            ContextMenu(label: title) do |menu|
              edit(menu) if writable?
              opens(menu)
              next unless writable?

              menu.separator
              deletes(menu)
            end
          end

          private

          def act(route) = path(route, id: @event.id)

          def delete(menu, label, scope = nil)
            fields = { day: @day.iso8601, scope: }.compact
            confirm = t(".confirm_delete")

            menu.post(label, action: act(:admin_delete_calendar_event), icon: :trash, warn: true, fields:, confirm:)
          end

          def deletes(menu)
            return delete(menu, t(".delete")) unless @event.recurring_id

            delete(menu, t(".delete_this"), "this")
            delete(menu, t(".delete_all"), "all")
          end

          def edit(menu)
            id = "cal-event-#{@event.id}-edit"

            menu.link(t(".edit"), href: path(:admin_calendar, day: @day.iso8601), icon: :edit,
                                  dialog: id)
            Dialog(id:, title: t(".edit_title"), class: "modal") do
              EventForm(action: act(:admin_update_calendar_event), day: @day, event: @event, morph: true)
            end
          end

          def opens(menu)
            menu.link(t(".join"), href: @event.meet_url, icon: "fa-solid fa-video", outbound: true) if @event.meet_url
            menu.link(t(".google"), href: @event.link, icon: :outbound, outbound: true) if @event.link
          end

          def title = @event.title || t("ui.components.calendar.event_row.untitled")

          def writable? = @event.calendar.writable
        end
      end
    end
  end
end
