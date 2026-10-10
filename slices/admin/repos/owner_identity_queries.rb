# frozen_string_literal: true

module Admin
  module Repos
    class OwnerIdentityQueries < Blog::DB::Repo
      def github?(id) = owner_identities.where(provider: "github", external_id: id.to_s).exist?
    end
  end
end
