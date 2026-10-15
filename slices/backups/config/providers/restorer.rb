# frozen_string_literal: true

Backups::Slice.register_provider :restorer do
  start do
    register "restorer", Backups::Restorer.new(database: target["settings"].database)
  end
end
