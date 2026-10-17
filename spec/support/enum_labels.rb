# frozen_string_literal: true

module Spec
  module EnumLabels
    def enum_labels(slice, type)
      db = slice["db.rom"].gateways[:default].connection
      label = Sequel.function(:unnest, Sequel.function(:enum_range, Sequel.cast(nil, type))).cast(:text)

      db.select(label.as(:label)).map(:label)
    end
  end
end

RSpec.configure do |config|
  config.include Spec::EnumLabels
end
