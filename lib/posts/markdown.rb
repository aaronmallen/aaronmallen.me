# frozen_string_literal: true

require "commonmarker"

module Posts
  module Markdown
    BREAK_NODES = %i[linebreak softbreak].freeze
    INLINE_NODES = %i[
      code emph escaped_tag image link spoiler_text strikethrough strong subscript superscript text underline
    ].freeze
    OPTIONS = { extension: { header_ids: nil }, render: { hardbreaks: false } }.freeze
    PLUGINS = { syntax_highlighter: { theme: Dry::Core::Constants::EMPTY_STRING } }.freeze
    TEXT_NODES = %i[code code_block text].freeze
    WORDS_PER_MINUTE = 220

    class << self
      def first_paragraph(markdown)
        paragraph = parse(markdown).find { it.type == :paragraph }
        return unless paragraph

        text = paragraph.walk.map { |node| inline_text(node) }.join.strip
        text unless text.empty?
      end

      def read_time(markdown) = [1, word_count(markdown).fdiv(WORDS_PER_MINUTE).round].max

      def to_html(markdown) = Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS)

      def word_count(markdown) = plain_text(markdown).split.size

      private

      def inline_text(node)
        return " " if BREAK_NODES.include?(node.type)

        TEXT_NODES.include?(node.type) ? node.string_content : Dry::Core::Constants::EMPTY_STRING
      end

      def parse(markdown) = Commonmarker.parse(markdown, options: OPTIONS)

      def plain_text(markdown)
        text = +""
        parse(markdown).walk do |node|
          text << " " unless INLINE_NODES.include?(node.type)
          text << node.string_content if TEXT_NODES.include?(node.type)
        end
        text
      end
    end
  end
end
