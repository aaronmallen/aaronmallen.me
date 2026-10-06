# frozen_string_literal: true

module Admin
  module UI
    module Components
      class RecordKey < Component
        COPIED = {
          Blog::Types::RecordKind["decision"] => ".copied.decision",
          Blog::Types::RecordKind["task"] => ".copied.task",
        }.freeze
        COPY = {
          Blog::Types::RecordKind["decision"] => ".copy.decision",
          Blog::Types::RecordKind["task"] => ".copy.task",
        }.freeze
        PREFIX = "#"

        prop :kind, Blog::Types::String.enum(*COPY.keys)
        prop :id, Blog::Types::Integer

        def view_template
          button(
            type: "button",
            class: "record-key",
            title: t(COPY.fetch(@kind), key:),
            data: { record_key: key, record_key_copied: t(COPIED.fetch(@kind), key:) },
          ) { key }
        end

        private

        def key = "#{PREFIX}#{@id}"
      end
    end
  end
end
