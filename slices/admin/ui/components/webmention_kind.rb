# frozen_string_literal: true

module Admin
  module UI
    module Components
      class WebmentionKind < Component
        KINDS = {
          Blog::Types::WebmentionType["reply"] => [:pink, "fa-solid fa-reply"],
          Blog::Types::WebmentionType["like"] => [:sand, "fa-solid fa-heart"],
          Blog::Types::WebmentionType["repost"] => [:green, "fa-solid fa-retweet"],
          Blog::Types::WebmentionType["mention"] => [:blue, "fa-solid fa-at"],
        }.freeze
        LABELS = "ui.components.webmention_kind.types"

        prop :type, Blog::Types::WebmentionType

        def self.label_key(type) = "#{LABELS}.#{type}"

        def view_template
          color, icon = KINDS.fetch(@type)

          span(class: ["wm-kind", color.to_s]) do
            Icon(icon)
            plain t(self.class.label_key(@type))
          end
        end
      end
    end
  end
end
