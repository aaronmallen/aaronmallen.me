# frozen_string_literal: true

require "zeitwerk"

module Markdown
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/markdown", namespace: self)
    loader.setup
  end

  WORDS_PER_MINUTE = 220

  class << self
    def size_images(html, &) = Document.size_images(html, &)

    def to_html(markdown) = Document.new(markdown).html

    def to_text(markdown) = Document.new(markdown).text
  end
end
