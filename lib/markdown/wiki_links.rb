# frozen_string_literal: true

require "nokogiri"

module Markdown
  module WikiLinks
    LITERAL = %w[a code pre].freeze
    MARKS = /[*_`]/
    PATTERN = /\[\[([^\]|\n]+)(?:\|([^\]\n]+))?\]\]/
    PIECES = /(\[\[[^\]|\n]+(?:\|[^\]\n]+)?\]\])/
    PREFIX = /\A[#>\-*\d.\s]+/
    WHOLE = /\A#{PATTERN}\z/

    class << self
      def link(html, &)
        fragment = Nokogiri::HTML5.fragment(html)
        texts(fragment).each { |node| node.replace(linked(node, &)) }
        fragment.to_html
      end

      def plain(line)
        line.gsub(PATTERN) do
          (Regexp.last_match(2) || Regexp.last_match(1)).strip
        end.sub(PREFIX, "").gsub(MARKS, "").strip
      end

      def rewrite(body, from, to)
        key = from.strip.downcase

        body.gsub(PATTERN) do
          title, text = Regexp.last_match.captures
          title.strip.downcase == key ? "[[#{to}#{"|#{text}" if text}]]" : Regexp.last_match(0)
        end
      end

      def titles(body) = body.scan(PATTERN).map { it.first.strip }.reject(&:empty?).uniq(&:downcase)

      private

      def element(document, piece)
        match = piece.match(WHOLE)
        title = match && match[1].strip
        return document.create_text_node(piece) if title.nil? || title.empty?

        name, attributes = yield title
        document.create_element(name, (match[2] || title).strip, attributes)
      end

      def linkable?(node)
        node.text? && node.content.match?(PATTERN) && node.ancestors.none? { LITERAL.include?(it.name) }
      end

      def linked(node, &)
        document = node.document

        Nokogiri::XML::NodeSet.new(document, node.content.split(PIECES).map { element(document, it, &) })
      end

      def texts(fragment)
        found = []
        fragment.traverse { found << it if linkable?(it) }
        found
      end
    end
  end
end
