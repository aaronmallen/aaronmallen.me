# frozen_string_literal: true

require "zeitwerk"

module ObjectStore
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/object_store", namespace: self)
    loader.setup
  end
end
