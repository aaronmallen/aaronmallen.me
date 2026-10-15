# frozen_string_literal: true

module Projects
  module Repos
    class ProjectMutations < Blog::DB::Repo
      root :projects

      stamped_commands :create, :update
      tagged_by :project_tags
    end
  end
end
