# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityQueries < Blog::DB::Repo
      def email?(email)
        email.is_a?(String) && owner_identities.where(Sequel.cast(:email, String) => email.downcase).exist?
      end
    end
  end
end
