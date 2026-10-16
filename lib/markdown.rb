# frozen_string_literal: true

module Markdown
  WORDS_PER_MINUTE = 220

  class << self
    def read_time(markdown) = Document.new(markdown).read_time

    def size_images(html, &) = Document.size_images(html, &)

    def to_html(markdown) = Document.new(markdown).html

    def to_text(markdown) = Document.new(markdown).text

    def word_count(markdown) = Document.new(markdown).word_count
  end
end
