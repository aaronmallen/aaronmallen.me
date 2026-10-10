# frozen_string_literal: true

module Projects
  module Repos
    class ProjectMutations < Blog::DB::Repo
      root :projects

      stamped_commands :create, :update

      def replace_tags(id, names) = project_tags.retag(id, names, tags)
    end
  end
end
