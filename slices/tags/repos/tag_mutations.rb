# frozen_string_literal: true

module Tags
  module Repos
    class TagMutations < Blog::DB::Repo
      root :tags

      stamped_commands :create, :update
      commands delete: :by_pk
    end
  end
end
