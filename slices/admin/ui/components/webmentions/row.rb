# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class Row < Component
          MODERATIONS = Blog::Types::WebmentionModeration.mapping

          prop :mention, Blog::Types::Instance(ROM::Struct)
          prop :slug, Blog::Types::String
          prop :filter, Blog::Types::String
          prop :bulk, Blog::Types::String

          def view_template
            data = { key_row: true, menu: path(:admin_webmention_menu, id: @mention.id) }

            Card(id: "webmention-#{@mention.id}", class: "wm-card", data:) do
              p(class: "inbox-meta") { meta }
              p(class: "wm-who") { author }
              WebmentionExcerpt(mention: @mention)
              spam_reason
              div(class: "wm-acts") { WebmentionVerdicts(actions: verdicts, kept: { status: @filter }) }
            end
          end

          private

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

          def pick = { form: @bulk, value: @mention.id, label: t(".pick", author: @mention.author_label) }

          def spam_reason
            return unless @mention.spam_reason

            p(class: "wm-reason") { t(".spam_reason", reason: @mention.spam_reason) }
          end

          def verdicts
            (Blog::Types::WebmentionVerdict.values - [@mention.status]).to_h do |status|
              [status, path(:admin_moderate_webmention, id: @mention.id, verdict: MODERATIONS.fetch(status))]
            end
          end
        end
      end
    end
  end
end
