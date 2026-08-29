# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class PendingCard < Component
          TYPES = {
            Blog::Types::WebmentionType["like"] => ".types.like",
            Blog::Types::WebmentionType["mention"] => ".types.mention",
            Blog::Types::WebmentionType["reply"] => ".types.reply",
            Blog::Types::WebmentionType["repost"] => ".types.repost",
          }.freeze
          PENDING = Blog::Types::WebmentionStatus["pending"]
          SEPARATOR = " · "

          prop :count, Blog::Types::Integer
          prop :mentions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title")) do |card|
              card.side { head }
              @mentions.each { |mention| row(mention) }
            end
          end

          private

          def head
            span(class: "wm-count") { t(".pending", count: @count) }
            a(class: "btn pri sm", href: review_path) { t(".review") }
          end

          def review_path = path(:admin_webmentions, status: PENDING)

          def row(mention)
            ListItem(title: mention.author_label, href: mention.source_url, sub: sub(mention))
          end

          def sub(mention)
            [t(TYPES.fetch(mention.type)), mention.excerpt.to_s.strip].reject(&:empty?).join(SEPARATOR)
          end
        end
      end
    end
  end
end
