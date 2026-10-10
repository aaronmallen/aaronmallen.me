# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTags < Blog::DB::Relation
      use :taggings, owner_key: :task_id

      schema :task_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def names_by_task(task_ids)
        name = Sequel[:tags][:name]

        found = dataset.unordered.join(:tags, id: :tag_id).where(task_id: task_ids)

        found.order(name).select(:task_id, name).to_hash_groups(:task_id, :name)
      end
    end
  end
end
