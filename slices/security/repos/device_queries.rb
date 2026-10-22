# frozen_string_literal: true

module Security
  module Repos
    class DeviceQueries < Blog::DB::Repo
      def known(id) = (id if id && devices.where(id:).exist?)

      def newest_first = devices.newest_first.with_last_sign_in.to_a
    end
  end
end
