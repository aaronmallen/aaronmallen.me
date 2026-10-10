# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class Row < Component
          APPROVED = Blog::Types::WebmentionStatus["approved"]
          IGNORED = Blog::Types::WebmentionStatus["ignored"]
          SPAM = Blog::Types::WebmentionStatus["spam"]

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String
          prop :filter, Blog::Types::String
          prop :bulk, Blog::Types::String

          def view_template
            article(id: "webmention-#{@mention.id}", class: "card wm-card", data: { key_row: true }) do
              p(class: "inbox-meta") { meta }
              p(class: "wm-who") { author }
              WebmentionExcerpt(mention: @mention)
              spam_reason
              div(class: "wm-acts") { actions }
            end
          end

          private

          def actions
            moderation(APPROVED, nil) unless @mention.status == APPROVED
            moderation(IGNORED, :gh, icon: false) unless @mention.status == IGNORED
            spam unless @mention.status == SPAM
          end

          def author
            a(href: @mention.source_url, class: "wm-author", data: { key_open: true }, **OUTBOUND) do
              @mention.author_label
            end
          end

          def meta
            BulkCheck(**pick)
            WebmentionKind(type: @mention.type)
            span { path(:post, slug: @slug) }
            Moment(at: @mention.received_at)
          end

          def moderation(status, variant, icon: true, **attributes)
            verdict = Blog::Types::WebmentionModeration.mapping.fetch(status)

            Form(action: path(:admin_moderate_webmention, id: @mention.id, verdict:), **attributes) do
              input(type: "hidden", name: "status", value: @filter)
              yield if block_given?
              WebmentionVerdict(verdict: status, variant:, icon:)
            end
          end

          def pick = { form: @bulk, value: @mention.id, label: t(".pick", author: @mention.author_label) }

          def spam
            moderation(SPAM, :warn, class: "wm-spam") do
              Input(name: "reason", placeholder: t(".reason"), aria: { label: t(".reason") })
            end
          end

          def spam_reason
            return unless @mention.spam_reason

            p(class: "wm-reason") { t(".spam_reason", reason: @mention.spam_reason) }
          end
        end
      end
    end
  end
end
