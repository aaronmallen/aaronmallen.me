# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityMutations < Blog::DB::Repo
      root :owner_identities

      def add_github(id) = owner_identities.dataset.insert_conflict.insert(provider: "github", external_id: id.to_s)
    end
  end
end
