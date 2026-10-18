# frozen_string_literal: true

require "zeitwerk"

module Mastodon
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/mastodon", namespace: self)
    loader.setup
  end
end
