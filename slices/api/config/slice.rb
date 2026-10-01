# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/api"), namespace: API)

    config.actions.csrf_protection = false

    export %w[operations.mint_token operations.revoke_token queries.live_tokens]
  end
end
