# frozen_string_literal: true

module Security
  class Slice < Hanami::Slice
    import keys: %w[operations.find_place], from: :analytics

    export %w[
      operations.record_sighting
      operations.record_sign_in
      repos.sighting_queries
      repos.sign_in_queries
    ]
  end
end
