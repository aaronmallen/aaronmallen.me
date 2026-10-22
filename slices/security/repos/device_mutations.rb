# frozen_string_literal: true

module Security
  module Repos
    class DeviceMutations < Blog::DB::Repo
      def delete_signed_in_before(time) = devices.signed_in_before(time).delete

      def sign_in(...) = devices.sign_in(...)

      def sign_out(id) = id ? devices.where(id:).update(signed_out_at: Time.now) : 0
    end
  end
end
