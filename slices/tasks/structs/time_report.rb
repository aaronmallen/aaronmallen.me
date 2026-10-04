# frozen_string_literal: true

module Tasks
  module Structs
    TimeReport = Data.define(:from, :to, :by, :seconds, :groups)
  end
end
