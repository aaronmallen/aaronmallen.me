# frozen_string_literal: true

require "commonmarker"

module Posts
  module Markdown
    ANCHOR = %r{<a [^>]*class="anchor"></a>}
    BREAK_NODES = %i[linebreak softbreak].freeze
    CAPTION = '<div class="cf"><span class="cf-n"><i class="fa-regular fa-file-code" aria-hidden="true"></i>' \
              "%s</span>%s</div>"
    FIGURE = '<figure class="fig">\\1 /><figcaption>\\2</figcaption></figure>'
    H2 = %r{<h2 id="([^"]*)">(.*?)</h2>}m
    HIGHLIGHTED_BLOCK = %r{<pre class="syntax-highlighting">.*?</pre>}m
    HIGHLIGHTER_CLASSES = /(?<=<span class=")[^"]+/
    IMAGE = "<img "
    INLINE_NODES = %i[
      code emph escaped_tag image link spoiler_text strikethrough strong subscript superscript text underline
    ].freeze
    LAZY_IMAGE = '<img loading="lazy" decoding="async" '
    LONE_TITLED_IMAGE = %r{<p>(<img [^>]*?) title="([^"]*)" /></p>}
    MEDIA_IMAGE = /<img (?=[^>]*src="[^"]*#{Blog::Types::PHOTO_REFERENCE}")/
    OPTIONS = { extension: { header_ids: Blog::Constants::EMPTY_STRING }, render: { hardbreaks: false } }.freeze
    PLUGINS = { syntax_highlighter: { theme: Blog::Constants::EMPTY_STRING } }.freeze
    TAG = /<[^>]*>/
    SIZED_IMAGE = '<img width="%d" height="%d" '
    TEXT_NODES = %i[code code_block text].freeze
    WORDS_PER_MINUTE = 220

    class << self
      def read_time(markdown) = Document.new(markdown).read_time

      def size_images(html)
        keys = html.scan(MEDIA_IMAGE).flatten.uniq
        return html if keys.empty?

        sizes = yield keys
        html.gsub(MEDIA_IMAGE) { (size = sizes[Regexp.last_match(1)]) ? format(SIZED_IMAGE, *size) : it }
      end

      def to_html(markdown) = Document.new(markdown).html

      def word_count(markdown) = Document.new(markdown).word_count
    end
  end
end
