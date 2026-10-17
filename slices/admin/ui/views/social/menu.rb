# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Social
        class Menu < View
          DRAFT = Blog::Types::SocialPostStatus["draft"]
          POSTED = Blog::Types::SocialPostStatus["posted"]

          layout nil

          prop :social_post, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::SocialQueue
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: head, return_to: @return_to) do |menu|
              edits(menu) if editable?
              menu.copy(t(".copy_text"), text:, copied: t(".copied_text"), icon: :copy)
              remove(menu) if editable?
            end
          end

          private

          def edit_path = path(:admin_social, filter: @filter, edit: @social_post.id)

          def editable? = @social_post.status != POSTED && @social_post.deliveries.empty?

          def edits(menu)
            menu.link(t(".edit"), href: edit_path, icon: :edit)
            menu.link(t(".linked"), href: "#{edit_path}##{Index::LINKS}", icon: "fa-solid fa-link")
          end

          def head = text.lines.first.to_s.strip

          def remove(menu)
            label = t(@social_post.status == DRAFT ? ".delete_draft" : ".remove")
            action = path(:admin_delete_social_post, id: @social_post.id)
            fields = { filter: @filter, return_to: nil }

            menu.separator
            menu.post(label, action:, fields:, icon: :trash, warn: true, confirm: :remove)
          end

          def text = @social_post.parts.map(&:body).join("\n\n")
        end
      end
    end
  end
end
