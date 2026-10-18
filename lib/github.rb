# frozen_string_literal: true

require "zeitwerk"

module GitHub
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/github", namespace: self)
    loader.setup
  end
end
