# frozen_string_literal: true

module SavedViews
  module Repos
    class SavedViewMutations < Blog::DB::Repo
      root :saved_views

      stamped_commands :create, :update
      commands delete: :by_pk
    end
  end
end
