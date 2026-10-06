# frozen_string_literal: true

module Media
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/media"), namespace: Media)

    export %w[
      operations.claim_photos operations.read_photo operations.release_photos operations.upload_photo
      queries.published_photo store.client
    ]
  end
end
