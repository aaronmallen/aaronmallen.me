# frozen_string_literal: true

module Social
  module Structs
    class NetworkCount < Data.define(:count, :over, :text)
      NONE = new(count: 0, over: false, text: "")
    end
  end
end
