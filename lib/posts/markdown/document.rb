# frozen_string_literal: true

require "cgi"

module Posts
  module Markdown
    class Document
      def initialize(markdown)
        @root = Commonmarker.parse(markdown, options: OPTIONS)
      end

      def first_paragraph
        paragraph = @root.find { it.type == :paragraph }
        return unless paragraph

        text = paragraph.walk.map { |node| inline_text(node) }.join.strip
        text unless text.empty?
      end

      def html
        names = @root.walk.select { it.type == :code_block }.map { it.fence_info.split(" ", 2)[1] }
        @root.to_html(options: OPTIONS, plugins: PLUGINS).gsub(HIGHLIGHTED_BLOCK) do |block|
          block = block.gsub(HIGHLIGHTER_CLASSES) { it.gsub(/\S+/, 'hl-\\0') }
          name = names.shift
          name ? format(CAPTION, CGI.escapeHTML(name), block) : block
        end
      end

      def read_time = [1, word_count.fdiv(WORDS_PER_MINUTE).round].max

      def word_count = plain_text.split.size

      private

      def inline_text(node)
        return " " if BREAK_NODES.include?(node.type)

        TEXT_NODES.include?(node.type) ? node.string_content : Blog::Constants::EMPTY_STRING
      end

      def plain_text
        text = +""
        @root.walk do |node|
          text << " " unless INLINE_NODES.include?(node.type)
          text << node.string_content if TEXT_NODES.include?(node.type)
        end
        text
      end
    end
  end
end
