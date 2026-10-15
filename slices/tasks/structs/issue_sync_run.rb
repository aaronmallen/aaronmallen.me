# frozen_string_literal: true

module Tasks
  module Structs
    IssueSyncRun = Data.define(:provider, :client, :now, :known) do
      def track(source)
        known[source.remote_id] = source
      end
    end
  end
end
