# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Menu < View
          include Components::Decisions

          CLOSINGS = {
            drop: { label: ".drop", title: ".drop_title", icon: :ban, variant: :warn },
            reopen: { label: ".reopen", title: ".reopen_title", icon: "fa-solid fa-rotate-left", variant: :pri },
          }.freeze

          layout nil

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: "#{key} · #{@decision.title}", return_to: @return_to) do |menu|
              opens(menu)
              tags(menu)
              menu.separator
              closing(menu, @decision.open? ? :drop : :reopen)
            end
          end

          private

          def act(route) = path(route, id: @decision.id)

          def closing(menu, name)
            id = "decision-#{@decision.id}-#{name}"
            label, title, icon, variant = CLOSINGS.fetch(name).values_at(:label, :title, :icon, :variant)

            menu.link(t(label), href: act(:admin_decision), icon:, dialog: id)
            Dialog(id:, title: t(title), class: "modal", data: { dialog: true }) do
              ReasonForm(
                decision: @decision, form: Blog::Constants::EMPTY_HASH, name:, route: :"admin_#{name}_decision",
                variant:, morph: true,
              ) { input(type: "hidden", name: "return_to", value: @return_to) if @return_to }
            end
          end

          def copied = t("ui.components.record_key.copied.decision", key:)

          def key = Components::RecordKey.key(@decision.id)

          def names = @decision.tags.map(&:name)

          def opens(menu)
            menu.link(t(".open"), href: act(:admin_decision), icon: "fa-regular fa-folder-open")
            menu.link(t(".edit"), href: act(:admin_edit_decision), icon: :edit)
            menu.copy(t(".copy_number"), text: key, copied:, icon: :copy, hint: key)
          end

          def tags(menu)
            tag_path = act(:admin_tag_decision)

            MenuTags(menu:, tags: @tags, names:, tag_path:, untag_path: act(:admin_untag_decision))
          end
        end
      end
    end
  end
end
