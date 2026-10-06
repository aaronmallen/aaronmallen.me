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
            ListItem(
              id: "webmention-#{@mention.id}", title: @mention.author_label, href: @mention.source_url, icon: type.icon,
              link: OUTBOUND, pick:,
            ) do |item|
              item.body { excerpt }
              item.meta do
                meta
                spam_reason
              end
              actions
            end
          end

          private

          def actions
            moderation(APPROVED, ".approve", :pri) unless @mention.status == APPROVED
            moderation(IGNORED, ".ignore", nil) unless @mention.status == IGNORED
            spam unless @mention.status == SPAM
          end

          def excerpt
            text = @mention.excerpt.to_s.strip

            p(class: ["wm-excerpt", ("quiet" if text.empty?)]) { text.empty? ? t(".no_content") : text }
          end

          def meta
            div(class: "wm-meta") do
              Pill(color: type.color) { t(type.label_key) }
              span { Stamped(text: dotted(path(:post, slug: @slug), Stamped::MARK), at: @mention.received_at) }
            end
          end

          def moderation(status, label_key, variant, **attributes)
            verdict = Blog::Types::WebmentionModeration.mapping.fetch(status)

            Form(action: path(:admin_moderate_webmention, id: @mention.id, verdict:), **attributes) do
              input(type: "hidden", name: "status", value: @filter)
              yield if block_given?
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def pick = { form: @bulk, value: @mention.id, label: t(".pick", author: @mention.author_label) }

          def spam
            moderation(SPAM, ".spam", :warn, class: "wm-spam") do
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
