# frozen_string_literal: true

module Backups
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/backups"), namespace: Backups)

    export []
  end
end
