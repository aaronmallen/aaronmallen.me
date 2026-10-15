# frozen_string_literal: true

module Posts
  module Helpers
    module Rendering
      BODY = %i[body_html first_paragraph read_time word_count].freeze
      NOTE = %i[note_html].freeze

      def self.body(markdown)
        document = ::Markdown::Document.new(markdown)

        { body_html: document.html, first_paragraph: document.first_paragraph, read_time: document.read_time,
          word_count: document.word_count }
      end

      def self.note(markdown) = { note_html: ::Markdown.to_html(markdown) }

      def self.with_body(attributes) = attributes.key?(:body) ? attributes.merge(body(attributes[:body])) : attributes

      def self.with_note(attributes) = attributes.key?(:note) ? attributes.merge(note(attributes[:note])) : attributes
    end
  end
end
