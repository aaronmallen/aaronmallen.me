# frozen_string_literal: true

module Shares
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/shares"), namespace: Shares)

    export %w[
      operations.delete_share operations.save_share operations.upload_share repos.share_queries
    ]
  end
end
