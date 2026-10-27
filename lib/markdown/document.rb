# frozen_string_literal: true

require "cgi"
require "commonmarker"

module Markdown
  class Document
    ANCHOR = %r{<a [^>]*class="anchor"></a>}
    BREAK_NODES = %i[linebreak softbreak].freeze
    CAPTION = '<div class="cf"><span class="cf-n"><i aria-hidden="true">' \
              "#{Blog::UI::Components::Icon::SVGS.fetch('regular/file-code')}</i>%s</span>%s</div>".freeze
    CODE = %r{(?<=<code>).*(?=</code>)}m
    FIGURE = '<figure class="fig">\\1 /><figcaption>\\2</figcaption></figure>'
    H2 = %r{<h2 id="([^"]*)">(.*?)</h2>}m
    HIGHLIGHTED_BLOCK = %r{<pre class="syntax-highlighting">.*?</pre>}m
    HIGHLIGHTER_CLASSES = /(?<=<span class=")[^"]+/
    IMAGE = "<img "
    INLINE_NODES = %i[
      code emph escaped_tag image link spoiler_text strikethrough strong subscript superscript text underline
    ].freeze
    LAZY_IMAGE = '<img loading="lazy" decoding="async" '
    LINE = '<span class="hl-ln">'
    LINE_END = "</span>"
    LONE_TITLED_IMAGE = %r{<p>(<img [^>]*?) title="([^"]*)" /></p>}
    MEDIA_IMAGE = /<img (?=[^>]*src="[^"]*#{Blog::Constants::MEDIA_REFERENCE}")/
    MERMAID = '<pre class="mermaid">%s</pre>'
    OPTIONS = { extension: { header_ids: Blog::Constants::EMPTY_STRING }, render: { hardbreaks: false } }.freeze
    PLUGINS = { syntax_highlighter: { theme: Blog::Constants::EMPTY_STRING } }.freeze
    TAG = /<[^>]*>/
    TOKEN = /<[^>]*>|[^<]+/
    TRAILING_LINE = /\n<span class="hl-ln">(?:<[^>]*>)*\z/
    SIZED_IMAGE = '<img width="%d" height="%d" '
    SIZES = "(min-width: 44em) 44em, 100vw"
    SRCSET_IMAGE = '<img width="%d" height="%d" srcset="%s" sizes="%s" '
    TEXT_NODES = %i[code code_block text].freeze

    def self.headings(html)
      html.scan(H2).filter_map do |id, text|
        { id:, text: CGI.unescapeHTML(text.gsub(TAG, Blog::Constants::EMPTY_STRING)).strip } unless id.empty?
      end
    end

    def self.size_images(html)
      keys = html.scan(MEDIA_IMAGE).flatten.uniq
      return html if keys.empty?

      photos = yield keys
      html.gsub(MEDIA_IMAGE) { (photo = photos[Regexp.last_match(1)]) ? sized_image(photo) : it }
    end

    def self.sized_image(photo)
      return format(SIZED_IMAGE, photo.width, photo.height) if photo.widths.empty?

      format(SRCSET_IMAGE, photo.width, photo.height, photo.srcset, SIZES)
    end
    private_class_method :sized_image

    def initialize(markdown)
      @root = Commonmarker.parse(markdown, options: OPTIONS)
      @root.walk { it.header_level = 2 if it.type == :heading && it.header_level == 1 }
    end

    def first_paragraph
      paragraph = @root.find { it.type == :paragraph }
      return unless paragraph

      text = paragraph.walk.map { |node| inline_text(node) }.join.strip
      text unless text.empty?
    end

    def headings = self.class.headings(html)

    def html = @html ||= render

    def read_time = [1, word_count.fdiv(WORDS_PER_MINUTE).round].max

    def text = plain_text.split.join(" ")

    def word_count = plain_text.split.size

    private

    def caption_code(html)
      nodes = @root.walk.select { it.type == :code_block }
      html.gsub(HIGHLIGHTED_BLOCK) { code_block(nodes.shift, it) }
    end

    def code_block(node, block)
      language, name = node.fence_info.split(" ", 2)
      return format(MERMAID, CGI.escapeHTML(node.string_content)) if language == "mermaid"

      block = block.gsub(HIGHLIGHTER_CLASSES) { it.gsub(/\S+/, 'hl-\\0') }.sub(CODE) { number_lines(it) }
      name ? format(CAPTION, CGI.escapeHTML(name), block) : block
    end

    def inline_text(node)
      return " " if BREAK_NODES.include?(node.type)

      TEXT_NODES.include?(node.type) ? node.string_content : Blog::Constants::EMPTY_STRING
    end

    def lazy_load(html)
      count = 0
      html.gsub(IMAGE) { (count += 1) > 1 ? LAZY_IMAGE : IMAGE }
    end

    def number_lines(code)
      open = []
      lines = code.scan(TOKEN).map do |token|
        if token == LINE_END then open.pop
        elsif token.start_with?("<") then open << token
        else next token.gsub("\n") { "#{LINE_END * (open.size + 1)}\n#{LINE}#{open.join}" }
        end
        token
      end
      "#{LINE}#{lines.join}#{LINE_END}".sub(TRAILING_LINE, Blog::Constants::EMPTY_STRING)
    end

    def plain_text
      text = +""
      @root.walk do |node|
        text << " " unless INLINE_NODES.include?(node.type)
        text << node.string_content if TEXT_NODES.include?(node.type)
      end
      text
    end

    def render
      html = @root.to_html(options: OPTIONS, plugins: PLUGINS).gsub(ANCHOR, Blog::Constants::EMPTY_STRING)
      html = caption_code(html)
      lazy_load(html.gsub(LONE_TITLED_IMAGE, FIGURE))
    end
  end
end
