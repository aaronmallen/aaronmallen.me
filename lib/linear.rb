# frozen_string_literal: true

require "zeitwerk"

module Linear
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/linear", namespace: self)
    loader.setup
  end
end
