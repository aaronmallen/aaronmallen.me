# frozen_string_literal: true

require "cgi"
require "commonmarker"

module Admin
  module InlineMarkdown
    Run = Data.define(:marks, :text)

    BREAKS = %i[linebreak softbreak thematic_break].freeze
    CODE = "code"
    CODE_NODES = %i[code code_block].freeze
    DROPPED = %i[html_block html_inline].freeze
    INLINE = %i[emph escaped_tag image link spoiler_text strikethrough strong subscript superscript underline].freeze
    MARKS = { emph: "em", strong: "strong" }.freeze
    SPACE = " "
    WHITESPACE = /\s+/

    class << self
      def to_html(markdown, keep:)
        runs = squish(collect(Commonmarker.parse(markdown.to_s, options: ::Posts::Markdown::OPTIONS), []))
        return render(runs) if length(runs) <= keep

        "#{render(rstrip(take(runs, keep)))}#{Blog::Truncation::MARK}"
      end

      private

      def collect(node, marks, runs = [])
        case node.type
        when *DROPPED then nil
        when :text then runs << Run.new(marks, node.string_content)
        when *CODE_NODES then runs << Run.new([*marks, CODE], node.string_content)
        when *BREAKS then runs << Run.new(marks, SPACE)
        else nest(node, marks, runs)
        end
        runs
      end

      def length(runs) = runs.sum { it.text.grapheme_clusters.length }

      def nest(node, marks, runs)
        inner = MARKS.key?(node.type) ? [*marks, MARKS.fetch(node.type)] : marks
        block = !INLINE.include?(node.type)

        runs << Run.new(marks, SPACE) if block
        node.each { collect(it, inner, runs) }
        runs << Run.new(marks, SPACE) if block
      end

      def render(runs)
        html = +""
        open = runs.reduce([]) do |marks, run|
          html << switch(marks, run.marks) << CGI.escapeHTML(run.text)
          run.marks
        end
        html << switch(open, [])
      end

      def rstrip(runs)
        runs = runs.dup
        runs.pop while runs.any? && runs.last.text.rstrip.empty?
        runs.empty? ? runs : [*runs[...-1], runs.last.with(text: runs.last.text.rstrip)]
      end

      def squish(runs)
        spaced = true
        squished = runs.filter_map do |run|
          text = run.text.gsub(WHITESPACE, SPACE)
          text = text.delete_prefix(SPACE) if spaced
          next if text.empty?

          spaced = text.end_with?(SPACE)
          run.with(text:)
        end
        rstrip(squished)
      end

      def switch(from, to)
        shared = from.zip(to).take_while { |was, now| was == now }.size
        closes = from.drop(shared).reverse.map { "</#{it}>" }

        [*closes, *to.drop(shared).map { "<#{it}>" }].join
      end

      def take(runs, keep)
        runs.each_with_object([]) do |run, kept|
          left = keep - length(kept)
          break kept if left <= 0

          clusters = run.text.grapheme_clusters
          kept << (clusters.length > left ? run.with(text: clusters.first(left).join) : run)
        end
      end
    end
  end
end
