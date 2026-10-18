# frozen_string_literal: true

require "zeitwerk"

module PageFetcher
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/page_fetcher", namespace: self)
    loader.setup
  end
end
