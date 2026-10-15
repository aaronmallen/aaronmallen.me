# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class BulkMenu < View
          ACT = Blog::Types::TaskBulkAction

          layout nil

          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :fields, Blog::Types::Hash

          def view_template
            ContextMenu(label: t(".label", count: @tasks.size)) do |menu|
              menu.post(t(".complete"), **act("complete"), icon: "fa-solid fa-check")
              moves(menu)
              tags(menu)
              menu.separator
              ends(menu)
              menu.separator
              menu.clear(t(".clear"), form: Components::Tasks::Bulk::ID)
            end
          end

          private

          def act(name, **) = { action:, fields: { **picked, act: ACT[name], ** } }

          def action = path(:admin_bulk_tasks)

          def ends(menu)
            confirm = t(".confirm_delete")

            menu.post(t(".cancel"), **act("cancel"), icon: :ban)
            menu.post(t(".delete"), **act("delete"), icon: :trash, warn: true, confirm:)
          end

          def held = @tasks.flat_map { it.tags.map(&:name) }.uniq.sort

          def invalid = t("tasks_page.toasts.bulk.invalid.tag_format")

          def moves(menu)
            menu.sub(t(".move"), icon: "fa-solid fa-arrow-right-arrow-left") do
              Blog::Types::TaskFilter.each_value do |list|
                menu.post(t(Helpers::TaskLists.title(list)), **act("move", to: list))
              end
            end
          end

          def picked = { **@fields, "ids[]": @tasks.map(&:id) }

          def tags(menu) = BulkTags(menu:, action:, fields: picked, tags: @tags.map(&:name), held:, invalid:)
        end
      end
    end
  end
end
