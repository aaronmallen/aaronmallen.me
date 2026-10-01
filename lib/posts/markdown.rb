# frozen_string_literal: true

require "commonmarker"

module Posts
  module Markdown
    BREAK_NODES = %i[linebreak softbreak].freeze
    INLINE_NODES = %i[
      code emph escaped_tag image link spoiler_text strikethrough strong subscript superscript text underline
    ].freeze
    OPTIONS = { extension: { header_ids: nil }, render: { hardbreaks: false } }.freeze
    PLUGINS = { syntax_highlighter: { theme: Blog::Constants::EMPTY_STRING } }.freeze
    TEXT_NODES = %i[code code_block text].freeze
    WORDS_PER_MINUTE = 220

    class << self
      def read_time(markdown) = Document.new(markdown).read_time

      def to_html(markdown) = Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS)

      def word_count(markdown) = Document.new(markdown).word_count
    end
  end
end
