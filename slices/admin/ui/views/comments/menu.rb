# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Comments
        class Menu < View
          ROUTES = {
            task: { page: :admin_task, delete: :admin_delete_task_comment },
            decision: { page: :admin_decision, delete: :admin_delete_decision_comment },
          }.freeze

          layout nil

          prop :comment, Blog::Types::Instance(ROM::Struct)
          prop :owner, Blog::Types::Symbol.enum(*ROUTES.keys)
          prop :owner_id, Blog::Types::Integer
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label:, return_to: @return_to) do |menu|
              @comment.synced? ? source(menu) : edit(menu)
              menu.copy(t(".copy_text"), text: @comment.body, copied: t(".copied_text"), icon: "fa-regular fa-copy")
              delete(menu) unless @comment.synced?
            end
          end

          private

          def anchor = "#{@owner}-comment-#{@comment.source_id}"

          def delete(menu)
            action = path(ROUTES.dig(@owner, :delete), id: @owner_id, comment_id: @comment.source_id)

            menu.separator
            menu.post(t(".delete"), action:, icon: "fa-regular fa-trash-can", warn: true, confirm: t(".confirm_delete"))
          end

          def edit(menu)
            href = "#{path(ROUTES.dig(@owner, :page), id: @owner_id)}##{anchor}"

            menu.link(t(".edit"), href:, icon: "fa-regular fa-pen-to-square", dialog: anchor)
          end

          def label = Admin::Short.title(@comment.body.lines.first.to_s.strip)

          def source(menu)
            icon = "fa-solid fa-arrow-up-right-from-square"

            menu.link(t(".view_source"), href: @comment.url, icon:, outbound: true)
          end
        end
      end
    end
  end
end
