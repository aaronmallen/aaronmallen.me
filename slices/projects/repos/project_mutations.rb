# frozen_string_literal: true

module Projects
  module Repos
    class ProjectMutations < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["public"]

      root :projects

      stamped_commands :create, :update

      def replace_tags(id, names) = project_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
    end
  end
end
