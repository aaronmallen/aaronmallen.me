# frozen_string_literal: true

module Social
  module Structs
    Link = Data.define(:byte_end, :byte_start, :url)
  end
end
