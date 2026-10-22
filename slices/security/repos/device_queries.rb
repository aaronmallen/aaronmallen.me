# frozen_string_literal: true

module Security
  module Repos
    class DeviceQueries < Blog::DB::Repo
      def by_id(id) = (devices.where(id:).one if Blog::Types::Uuid.valid?(id))

      def known(id) = (id if id && devices.where(id:).exist?)

      def newest_first = devices.newest_first.with_last_sign_in.to_a

      def signed_in_since?(id, time) = !id.nil? && devices.where(id:).where { last_signed_in_at > time }.exist?
    end
  end
end
