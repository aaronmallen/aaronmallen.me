# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class BulkMenu < View
          DELETE = Blog::Types::PostBulkAction["delete"]

          layout nil

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :fields, Blog::Types::Hash

          def view_template
            ContextMenu(label: t(".label", count: @posts.size)) do |menu|
              BulkTags(menu:, action:, fields: picked, tags: @tags.map(&:name), held:, invalid:)
              menu.separator
              delete(menu)
            end
          end

          private

          def action = path(:admin_bulk_posts)

          def delete(menu)
            fields = { **picked, act: DELETE }
            confirm = t(".confirm_delete")

            menu.post(t(".delete"), action:, fields:, icon: "fa-regular fa-trash-can", warn: true, confirm:)
          end

          def held = @posts.flat_map { it.tags.map(&:name) }.uniq.sort

          def invalid = t("posts_page.toasts.bulk.invalid.tag_format")

          def picked = { **@fields, "ids[]": @posts.map(&:id) }
        end
      end
    end
  end
end
