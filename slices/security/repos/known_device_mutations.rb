# frozen_string_literal: true

module Security
  module Repos
    class KnownDeviceMutations < DB::Repo
      def know(at: Time.now, **row) = known_devices.know(row, at:)
    end
  end
end
