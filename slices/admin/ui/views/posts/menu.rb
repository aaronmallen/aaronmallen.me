# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Menu < View
          DELETE = Blog::Types::PostBulkAction["delete"]
          DRAFT = Blog::Types::PostStatus["draft"]
          EDIT = "fa-regular fa-pen-to-square"
          OUTBOUND = "fa-solid fa-arrow-up-right-from-square"
          PUBLISHED = Blog::Types::PostStatus["published"]
          TAG = Blog::Types::PostBulkAction["tag"]
          UNTAG = Blog::Types::PostBulkAction["untag"]

          layout nil

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :list, Blog::Types::Hash
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @post.title, return_to: @return_to) do |menu|
              menu.link(t(draft? ? ".keep_writing" : ".edit"), href: act(:admin_edit_post), icon: EDIT)
              published(menu) if published?
              menu.separator
              tags(menu)
              link_copy(menu) if published?
              delete(menu) if draft?
            end
          end

          private

          def act(route) = path(route, id: @post.id)

          def delete(menu)
            fields = { act: DELETE, "ids[]": @post.id, status: @list[:status],
                       **Blog::Structs::Page.query(@list[:page]), return_to: nil }

            menu.separator
            menu.post(t(".delete"), action: path(:admin_bulk_posts), fields:, icon: "fa-regular fa-trash-can",
                                    warn: true, confirm: t(".confirm_delete"))
          end

          def draft? = @post.status == DRAFT

          def link_copy(menu)
            menu.copy(t(".copy_link"), text: public_url, copied: t(".copied_link"), icon: "fa-solid fa-link")
          end

          def public_url = url(:post, slug: @post.slug).to_s

          def published(menu)
            menu.link(t(".analytics"), href: act(:admin_post_analytics), icon: "fa-solid fa-chart-simple")
            menu.link(t(".view"), href: public_url, icon: OUTBOUND, outbound: true)
          end

          def published? = @post.status == PUBLISHED

          def tags(menu)
            names = @post.tags.map(&:name)
            invalid = t("posts_page.toasts.bulk.invalid.tag_format")

            menu.tags(t(".tags"), names:, tags: @tags, new_tag: t(".new_tag"), invalid:) do |name, on|
              tag = name ? { tag: name } : Blog::Constants::EMPTY_HASH

              { action: path(:admin_bulk_posts), fields: { act: on ? UNTAG : TAG, "ids[]": @post.id, **tag } }
            end
          end
        end
      end
    end
  end
end
