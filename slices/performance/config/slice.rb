# frozen_string_literal: true

module Performance
  class Slice < Hanami::Slice
    export %w[operations.record_timing]
  end
end
