# frozen_string_literal: true

module Agents
  module Relations
    class MemoryFiles < Blog::DB::Relation
      SCOPE = Blog::Types::MemoryScope

      schema :memory_files, infer: true do
        associations do
          has_many :memory_facts, view: :live_in_order
          has_many :memory_file_tags
          has_many :tags, through: :memory_file_tags, view: :in_name_order
        end
      end

      def in_load_order = order(self[:scope].asc, self[:path].asc, self[:id].asc)

      def linkable = linkables(title: :path, day: self.class.site_day(:created_at))

      def loading(project_ids:, task_ids:)
        where(
          Sequel.|(
            { scope: SCOPE["global"] }, { scope: SCOPE["project"], project_id: project_ids },
            { scope: SCOPE["task"], task_id: task_ids },
          ),
        )
      end

      def matching(text) = containing(text, :path)
    end
  end
end
