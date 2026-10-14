# frozen_string_literal: true

module Performance
  class Slice < Hanami::Slice
    import keys: %w[operations.classify_device], from: :analytics

    export %w[operations.record_page_timing operations.record_timing]
  end
end
