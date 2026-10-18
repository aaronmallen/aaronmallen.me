# frozen_string_literal: true

require "zeitwerk"

module LinkedIn
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/linkedin", namespace: self)
    loader.setup
  end
end
