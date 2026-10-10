# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MentionItem < Component
          APPROVED = Blog::Types::WebmentionStatus["approved"]
          IGNORED = Blog::Types::WebmentionStatus["ignored"]
          SPAM = Blog::Types::WebmentionStatus["spam"]

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String

          def view_template
            Row(
              id: "webmention-#{@mention.id}", kind: :webmention, title: @mention.author_label,
              href: @mention.source_url, link: OUTBOUND,
            ) do |row|
              row.meta { meta }
              row.body { WebmentionExcerpt(mention: @mention, class: "inbox-row-body") }
              actions
            end
          end

          private

          def actions
            moderate(APPROVED, nil)
            moderate(IGNORED, :gh)
            moderate(SPAM, :warn, class: "wm-spam") do
              Input(name: "reason", placeholder: t(".reason"), aria: { label: t(".reason") })
            end
            Inbox::Snooze(kind: "webmention", id: @mention.id)
          end

          def meta
            span { Stamped(text: Stamped::MARK, at: @mention.received_at) }
            span { summary }
          end

          def moderate(verdict, variant, **attributes)
            Form(action: path(:admin_inbox_moderate_webmention, id: @mention.id, verdict:), **attributes) do
              yield if block_given?
              WebmentionVerdict(verdict:, variant:, icon: false)
            end
          end

          def summary = t(".summary", type:, path: path(:post, slug: @slug))

          def type = t(WebmentionKind.label_key(@mention.type))
        end
      end
    end
  end
end
