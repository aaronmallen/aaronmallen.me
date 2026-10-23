# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTags < Blog::DB::Relation
      use :taggings

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

      def tag_in_projects(task_ids, names, tags)
        by_project = tasks.where(id: task_ids).pluck(:id, :project_id).group_by(&:last)

        by_project.each { |project_id, held| tag(held.map(&:first), names, tags, project_id:) }
      end
    end
  end
end
