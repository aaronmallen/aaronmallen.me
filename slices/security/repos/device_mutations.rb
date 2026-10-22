# frozen_string_literal: true

module Security
  module Repos
    class DeviceMutations < Blog::DB::Repo
      def delete_signed_in_before(time) = devices.signed_in_before(time).delete

      def sign_in(...) = devices.sign_in(...)
    end
  end
end
