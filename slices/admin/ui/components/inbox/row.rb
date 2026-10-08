# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class Row < Component
          prop :id, Blog::Types::String
          prop :kind, Blog::Types::Symbol.enum(:task, :message, :webmention)
          prop :title, Blog::Types::String
          prop :href, Blog::Types::String.optional, default: nil
          prop :link, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def body(&block)
            @body = block
            nil
          end

          def meta(&block)
            @meta = block
            nil
          end

          def view_template(&)
            acts = capture(&)

            div(id: @id, class: "inbox-row", data: { key_row: true }) do
              div(class: "inbox-row-main") { render_main }
              div(class: "inbox-row-acts") { raw(safe(acts)) }
            end
          end

          private

          def render_main
            p(class: "inbox-meta") do
              KindLabel(kind: @kind)
              @meta&.call
            end
            render_title
            @body&.call
          end

          def render_title
            return p(class: "inbox-row-title") { @title } unless @href

            a(**mix({ class: "inbox-row-title", href: @href, data: { key_open: true } }, @link)) { @title }
          end
        end
      end
    end
  end
end
