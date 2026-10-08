# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class Row < Component
          APPROVED = Blog::Types::WebmentionStatus["approved"]
          IGNORED = Blog::Types::WebmentionStatus["ignored"]
          LIKE = Blog::Types::WebmentionType["like"]
          MENTION = Blog::Types::WebmentionType["mention"]
          OUTBOUND = { target: "_blank", rel: "noopener noreferrer" }.freeze
          REPLY = Blog::Types::WebmentionType["reply"]
          REPOST = Blog::Types::WebmentionType["repost"]
          SPAM = Blog::Types::WebmentionStatus["spam"]
          Type = Data.define(:color, :icon, :label_key)

          TYPES = {
            REPLY => Type.new(color: :pink, icon: "fa-solid fa-reply", label_key: ".types.reply"),
            LIKE => Type.new(color: :sand, icon: "fa-solid fa-heart", label_key: ".types.like"),
            REPOST => Type.new(color: :green, icon: "fa-solid fa-retweet", label_key: ".types.repost"),
            MENTION => Type.new(color: :blue, icon: "fa-solid fa-at", label_key: ".types.mention"),
          }.freeze

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String
          prop :filter, Blog::Types::String
          prop :bulk, Blog::Types::String

          def view_template
            article(id: "webmention-#{@mention.id}", class: "card wm-card", data: { key_row: true }) do
              p(class: "inbox-meta") { meta }
              p(class: "wm-who") { author }
              excerpt
              spam_reason
              div(class: "wm-acts") { actions }
            end
          end

          private

          def actions
            moderation(APPROVED, ".approve", nil, icon: "fa-solid fa-check") unless @mention.status == APPROVED
            moderation(IGNORED, ".ignore", :gh) unless @mention.status == IGNORED
            spam unless @mention.status == SPAM
          end

          def author
            a(href: @mention.source_url, class: "wm-author", data: { key_open: true }, **OUTBOUND) do
              @mention.author_label
            end
          end

          def excerpt
            text = @mention.excerpt.to_s.strip

            p(class: ["wm-excerpt", ("quiet" if text.empty?)]) { text.empty? ? t(".no_content") : text }
          end

          def meta
            BulkCheck(**pick)
            span(class: ["wm-kind", type.color.to_s]) do
              Icon(type.icon)
              plain t(type.label_key)
            end
            span { path(:post, slug: @slug) }
            Moment(at: @mention.received_at)
          end

          def moderation(status, label_key, variant, icon: nil, **attributes)
            verdict = Blog::Types::WebmentionModeration.mapping.fetch(status)

            Form(action: path(:admin_moderate_webmention, id: @mention.id, verdict:), **attributes) do
              input(type: "hidden", name: "status", value: @filter)
              yield if block_given?
              Button(type: "submit", variant:, small: true, icon:) { t(label_key) }
            end
          end

          def pick = { form: @bulk, value: @mention.id, label: t(".pick", author: @mention.author_label) }

          def spam
            moderation(SPAM, ".spam", :warn, icon: "fa-solid fa-ban", class: "wm-spam") do
              Input(name: "reason", placeholder: t(".reason"), aria: { label: t(".reason") })
            end
          end

          def spam_reason
            return unless @mention.spam_reason

            p(class: "wm-reason") { t(".spam_reason", reason: @mention.spam_reason) }
          end

          def type = TYPES.fetch(@mention.type)
        end
      end
    end
  end
end
