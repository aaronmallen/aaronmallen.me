# frozen_string_literal: true

module Security
  class Slice < Hanami::Slice
    import keys: %w[operations.find_place operations.hash_visitor], from: :analytics

    export %w[
      operations.record_sighting
      operations.record_sign_in
      operations.sign_out_device
      repos.device_queries
      repos.sighting_queries
      repos.sign_in_queries
    ]
  end
end
