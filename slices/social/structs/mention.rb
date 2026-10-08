# frozen_string_literal: true

module Social
  module Structs
    Mention = Data.define(:byte_end, :byte_start, :did)
  end
end
