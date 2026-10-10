# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityMutations < Blog::DB::Repo
      GITHUB = Blog::Types::ServiceProvider["github"]

      root :owner_identities

      def add_github(id) = owner_identities.dataset.insert_conflict.insert(provider: GITHUB, external_id: id.to_s)
    end
  end
end
