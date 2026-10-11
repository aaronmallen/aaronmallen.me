# frozen_string_literal: true

module Shares
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/shares"), namespace: Shares)

    export %w[
      operations.change_share_code operations.delete_share operations.set_share_alt_text operations.upload_share
      repos.share_queries
    ]
  end
end
