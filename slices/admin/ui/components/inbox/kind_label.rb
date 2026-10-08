# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class KindLabel < Component
          Kind = Data.define(:label_key, :tone)

          KINDS = {
            task: Kind.new(label_key: ".kinds.task", tone: "violet"),
            message: Kind.new(label_key: ".kinds.message", tone: "blue"),
            webmention: Kind.new(label_key: ".kinds.webmention", tone: "pink"),
          }.freeze

          prop :kind, Blog::Types::Symbol

          def view_template
            kind = KINDS.fetch(@kind)

            span(class: ["inbox-kind", kind.tone]) { t(kind.label_key) }
          end
        end
      end
    end
  end
end
