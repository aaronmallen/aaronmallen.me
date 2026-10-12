# frozen_string_literal: true

module Projects
  module Repos
    class ProjectMutations < Blog::DB::Repo
      root :projects

      stamped_commands :create, :update

      def add_tag(id, name)
        update(id, {}) unless project_tags.tag(id, [name], tags).empty?
      end

      def remove_tag(id, name)
        update(id, {}) if project_tags.untag(id, [name], tags).positive?
      end

      def replace_tags(id, names) = project_tags.retag(id, names, tags)
    end
  end
end
