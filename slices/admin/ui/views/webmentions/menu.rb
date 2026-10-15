# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Menu < View
          PENDING = Blog::Types::WebmentionStatus["pending"]
          SPAM = Blog::Types::WebmentionVerdict["spam"]
          VERDICTS = {
            Blog::Types::WebmentionVerdict["approved"] => [".approve", "fa-solid fa-check"],
            Blog::Types::WebmentionVerdict["ignored"] => [".ignore", "fa-regular fa-eye-slash"],
            SPAM => [".spam", :ban],
          }.freeze

          layout nil

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: "#{@mention.author_label} · #{type}", return_to: @return_to) do |menu|
              menu.link(t(".open_source"), href: source, icon: :outbound, outbound: true)
              menu.separator
              moderation(menu)
              menu.separator
              records(menu)
            end
          end

          private

          def moderation(menu)
            VERDICTS.each { |status, (key, icon)| verdict(menu, status, key, icon) }
            Components::Inbox::SnoozeMenu(menu:, kind: "webmention", id: @mention.id) if @mention.status == PENDING
          end

          def records(menu)
            menu.copy(t(".copy_source"), text: source, copied: t(".copied_source"), icon: :copy)
            menu.link(t(".go_to_post"), href: path(:admin_edit_post, id: @mention.post_id),
                                        icon: "fa-solid fa-file-lines")
          end

          def source = @mention.source_url

          def type = t(Components::WebmentionKind.label_key(@mention.type))

          def verdict(menu, status, key, icon)
            return if @mention.status == status

            verdict = Blog::Types::WebmentionModeration.mapping.fetch(status)
            menu.post(t(key), action: path(:admin_moderate_webmention, id: @mention.id, verdict:), icon:,
                              warn: status == SPAM)
          end
        end
      end
    end
  end
end
