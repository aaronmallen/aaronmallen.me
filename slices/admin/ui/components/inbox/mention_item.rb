# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MentionItem < Component
          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String

          def view_template
            Row(
              id: "webmention-#{@mention.id}", kind: :webmention, title: @mention.author_label,
              href: @mention.source_url, link: OUTBOUND, menu: path(:admin_webmention_menu, id: @mention.id),
            ) do |row|
              row.meta { meta }
              row.body { WebmentionExcerpt(mention: @mention, class: "inbox-row-body") }
              actions
            end
          end

          private

          def actions
            WebmentionVerdicts(actions: verdicts, icons: false)
            Inbox::Snooze(kind: "webmention", id: @mention.id)
          end

          def meta
            span { Stamped(text: Stamped::MARK, at: @mention.received_at) }
            span { summary }
          end

          def summary = t(".summary", type:, path: path(:post, slug: @slug))

          def type = t(WebmentionKind.label_key(@mention.type))

          def verdicts
            Blog::Types::WebmentionVerdict.values.to_h do |verdict|
              [verdict, path(:admin_inbox_moderate_webmention, id: @mention.id, verdict:)]
            end
          end
        end
      end
    end
  end
end
