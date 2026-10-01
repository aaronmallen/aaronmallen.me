# frozen_string_literal: true

module Media
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/media"), namespace: Media)

    export %w[store.client]
  end
end
