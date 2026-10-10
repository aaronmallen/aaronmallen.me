# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityQueries < Blog::DB::Repo
      GITHUB = Blog::Types::ServiceProvider["github"]

      def github?(id) = owner_identities.where(provider: GITHUB, external_id: id.to_s).exist?
    end
  end
end
