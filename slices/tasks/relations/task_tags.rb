# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :task_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def owner_key = :task_id
    end
  end
end
