# frozen_string_literal: true

module Tasks
  module Structs
    IssueSyncRun = Data.define(:provider, :client, :now, :known, :held, :linked, :checked) do
      def initialize(held: {}, linked: [], checked: [], **) = super

      def check(source, stamp) = stamp && (checked << source.id)

      def track(source)
        known[source.remote_id] = source
      end

      def unseen(assigned)
        known.except(*assigned.map { it[:id] }).values.select { it.due?(now) }.to_h { [it.remote_id, it.url] }
      end
    end
  end
end
