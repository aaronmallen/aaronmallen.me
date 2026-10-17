# frozen_string_literal: true

module Media
  class Slice < Hanami::Slice
    export %w[
      operations.claim_photo_keys operations.claim_photos operations.process_photo operations.read_photo
      operations.release_photos operations.upload_photo repos.photo_queries
    ]
  end
end
