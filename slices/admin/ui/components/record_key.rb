# frozen_string_literal: true

module Admin
  module UI
    module Components
      class RecordKey < Component
        COPIED = {
          Blog::Types::RecordKind["artifact"] => ".copied.artifact",
          Blog::Types::RecordKind["decision"] => ".copied.decision",
          Blog::Types::RecordKind["task"] => ".copied.task",
        }.freeze
        COPY = {
          Blog::Types::RecordKind["artifact"] => ".copy.artifact",
          Blog::Types::RecordKind["decision"] => ".copy.decision",
          Blog::Types::RecordKind["task"] => ".copy.task",
        }.freeze
        PREFIX = "#"

        def self.key(id) = "#{PREFIX}#{id}"

        prop :kind, Blog::Types::String.enum(*COPY.keys)
        prop :label, Blog::Types::String

        def view_template
          CopyButton(
            value: key, copied: t(COPIED.fetch(@kind), key:), bare: true, class: "record-key",
            title: t(COPY.fetch(@kind), key:),
          ) { key }
        end

        private

        def key = @label
      end
    end
  end
end
