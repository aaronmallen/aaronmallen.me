# frozen_string_literal: true

require "zeitwerk"

module Bluesky
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/bluesky", namespace: self)
    loader.setup
  end
end
