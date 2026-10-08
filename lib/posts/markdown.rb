# frozen_string_literal: true

require "commonmarker"

module Posts
  module Markdown
    BREAK_NODES = %i[linebreak softbreak].freeze
    HIGHLIGHTED_BLOCK = %r{<pre class="syntax-highlighting">.*?</pre>}m
    HIGHLIGHTER_CLASSES = /(?<=<span class=")[^"]+/
    INLINE_NODES = %i[
      code emph escaped_tag image link spoiler_text strikethrough strong subscript superscript text underline
    ].freeze
    OPTIONS = { extension: { header_ids: nil }, render: { hardbreaks: false } }.freeze
    PLUGINS = { syntax_highlighter: { theme: Blog::Constants::EMPTY_STRING } }.freeze
    TEXT_NODES = %i[code code_block text].freeze
    WORDS_PER_MINUTE = 220

    class << self
      def prefix_highlighter_classes(html)
        html.gsub(HIGHLIGHTED_BLOCK) { it.gsub(HIGHLIGHTER_CLASSES) { it.gsub(/\S+/, 'hl-\\0') } }
      end

      def read_time(markdown) = Document.new(markdown).read_time

      def to_html(markdown)
        prefix_highlighter_classes(Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS))
      end

      def word_count(markdown) = Document.new(markdown).word_count
    end
  end
end
