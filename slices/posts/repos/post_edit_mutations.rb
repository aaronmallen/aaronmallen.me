# frozen_string_literal: true

module Posts
  module Repos
    class PostEditMutations < DB::Repo
      root :post_edits

      stamped_commands :create, :update
    end
  end
end
