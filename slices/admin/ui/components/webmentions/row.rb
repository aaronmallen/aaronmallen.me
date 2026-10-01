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
          SEPARATOR = " · "

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String
          prop :filter, Blog::Types::String

          def view_template
            div(class: "li") do
              div(class: "li-main") do
                author
                excerpt
                meta
                spam_reason
              end
              div(class: "li-side") { actions }
            end
          end

          private

          def actions
            moderation(:admin_approve_webmention, ".approve", :pri) unless @mention.status == APPROVED
            moderation(:admin_ignore_webmention, ".ignore", nil) unless @mention.status == IGNORED
            spam unless @mention.status == SPAM
          end

          def author
            div(class: "wm-author") do
              i(class: [type.icon, "wm-type-icon"], aria: { hidden: "true" })
              a(class: "li-title", href: @mention.source_url, target: "_blank", rel: "noopener noreferrer") do
                @mention.author_label
              end
            end
          end

          def excerpt
            text = @mention.excerpt.to_s.strip

            p(class: ["wm-excerpt", ("quiet" if text.empty?)]) { text.empty? ? t(".no_content") : text }
          end

          def meta
            div(class: "wm-meta") do
              Pill(color: type.color) { t(type.label_key) }
              span { [path(:post, slug: @slug), l(Blog::TimeZone.local(@mention.received_at), format: :medium)].join(SEPARATOR) }
            end
          end

          def moderation(route, label_key, variant, **attributes)
            Form(action: path(route, id: @mention.id), **attributes) do
              input(type: "hidden", name: "status", value: @filter)
              yield if block_given?
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def spam
            moderation(:admin_spam_webmention, ".spam", :warn, class: "wm-spam") do
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
