# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MentionItem < Component
          APPROVED = Blog::Types::WebmentionStatus["approved"]
          IGNORED = Blog::Types::WebmentionStatus["ignored"]
          OUTBOUND = { target: "_blank", rel: "noopener noreferrer" }.freeze
          SEPARATOR = " · "
          SPAM = Blog::Types::WebmentionStatus["spam"]
          TYPES = {
            Blog::Types::WebmentionType["like"] => ".types.like",
            Blog::Types::WebmentionType["mention"] => ".types.mention",
            Blog::Types::WebmentionType["reply"] => ".types.reply",
            Blog::Types::WebmentionType["repost"] => ".types.repost",
          }.freeze

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String

          def view_template
            ListItem(title: @mention.author_label, href: @mention.source_url, link: OUTBOUND) do |item|
              item.body { excerpt }
              item.meta { p(class: "wm-meta") { meta } }
              actions
            end
          end

          private

          def actions
            moderate(APPROVED, ".approve", :pri)
            moderate(IGNORED, ".ignore", nil)
            moderate(SPAM, ".spam", :warn, class: "wm-spam") do
              Input(name: "reason", placeholder: t(".reason"), aria: { label: t(".reason") })
            end
          end

          def excerpt
            text = @mention.excerpt.to_s.strip

            p(class: ["wm-excerpt", ("quiet" if text.empty?)]) { text.empty? ? t(".no_content") : text }
          end

          def meta
            Pill(color: :pink) { t(".kind") }
            span { [t(TYPES.fetch(@mention.type)), path(:post, slug: @slug), received].join(SEPARATOR) }
          end

          def moderate(verdict, label_key, variant, **attributes)
            Form(action: path(:admin_inbox_moderate_webmention, id: @mention.id, verdict:), **attributes) do
              yield if block_given?
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def received = l(Blog::TimeZone.local(@mention.received_at), format: :medium)
        end
      end
    end
  end
end
