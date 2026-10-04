# frozen_string_literal: true

Backups::Slice.register_provider :dumper do
  start do
    register "dumper", Backups::Dumper.new(database: target["settings"].database)
  end
end
