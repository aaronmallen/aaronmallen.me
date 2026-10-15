# frozen_string_literal: true

module Posts
  module Repos
    class PostEditMutations < Blog::DB::Repo
      module Rendered
        def create(attributes = {}, **fields) = super(Helpers::Rendering.with_note(attributes.merge(fields)))

        def update(id, attributes = {}, **fields) = super(id, Helpers::Rendering.with_note(attributes.merge(fields)))
      end

      prepend Rendered

      root :post_edits

      stamped_commands :create, :update
    end
  end
end
