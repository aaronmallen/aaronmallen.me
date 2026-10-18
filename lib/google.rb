# frozen_string_literal: true

require "zeitwerk"

module Google
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/google", namespace: self)
    loader.setup
  end
end
