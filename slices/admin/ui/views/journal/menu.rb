# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Journal
        class Menu < View
          layout nil

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label:, return_to: @return_to) do |menu|
              opens(menu)
              tags(menu)
              menu.copy(t(".copy_text"), text: @entry.body, copied: t(".copied_text"), icon: :copy)
              menu.separator
              delete(menu)
            end
          end

          private

          def act(route) = path(route, id: @entry.id)

          def delete(menu)
            menu.post(t(".delete"), action: act(:admin_delete_journal_entry), icon: :trash, warn: true,
                                    confirm: :forever)
          end

          def edit_path = path(:admin_journal, to: @entry.entry_date.iso8601, edit: @entry.id)

          def label = "#{l(@entry.entry_date, format: :short)} · #{l(@entry.entry_time, format: :clock)}"

          def links_path = "#{edit_path}##{Components::Journal::Entry.links_id(@entry.id)}"

          def names = @entry.tags.map(&:name)

          def opens(menu)
            menu.link(t(".edit"), href: edit_path, icon: :edit)
            menu.link(t(".links"), href: links_path, icon: "fa-solid fa-link")
          end

          def tags(menu)
            tag_path = act(:admin_tag_journal_entry)

            MenuTags(menu:, tags: @tags, names:, tag_path:, untag_path: act(:admin_untag_journal_entry))
          end
        end
      end
    end
  end
end
