# frozen_string_literal: true

module Security
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/security"), namespace: Security)

    import keys: %w[operations.find_place], from: :analytics

    export %w[operations.record_sign_in]
  end
end
