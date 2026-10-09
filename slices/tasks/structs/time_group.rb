# frozen_string_literal: true

module Tasks
  module Structs
    TimeGroup = Data.define(:key, :name, :seconds, :shared, :overlapped, :tasks)
  end
end
