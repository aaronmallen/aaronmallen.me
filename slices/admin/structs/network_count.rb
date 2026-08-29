# frozen_string_literal: true

module Admin
  module Structs
    class NetworkCount < Data.define(:count, :over)
      NONE = new(count: 0, over: false)
    end
  end
end
