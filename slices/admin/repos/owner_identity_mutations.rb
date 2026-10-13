# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityMutations < Blog::DB::Repo
      root :owner_identities

      def add(email) = owner_identities.dataset.insert_conflict.insert(email: email.downcase)
    end
  end
end
