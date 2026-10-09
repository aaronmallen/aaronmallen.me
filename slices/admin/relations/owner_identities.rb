# frozen_string_literal: true

module Admin
  module Relations
    class OwnerIdentities < Blog::DB::Relation
      schema :owner_identities, infer: true
    end
  end
end
