# frozen_string_literal: true

module Activity
  module Relations
    class ReviewTasks < Blog::DB::Relation
      use :crediting

      DONE = Blog::Types::TaskStatus["done"]
      OWNER = Sequel[:review_tasks][:task_id]
      PROJECT = Blog::Types::RecordKind["project"]
      PROJECT_NAME = Sequel.cast(Sequel[:projects][:name], :text)
      TAG_NAME = Sequel.cast(Sequel[:tags][:name], :text)
      TASK = Blog::Types::RecordKind["task"]

      schema :review_tasks, infer: true

      def done_between(from, to)
        where(status: DONE, closed_on: from..to).order(self[:closed_on].asc, self[:task_id].asc)
      end

      def with_groups = select_append(listed(tag_names, :tags), listed(project_names, :projects))

      private

      def listed(names, name) = ROM::SQL::Attribute[ROM::Types::Any].meta(sql_expr: names).as(name)

      def names(rows, column) = rows.select(Sequel.function(:array_agg, column).order(column))

      def project_names
        links = dataset.db[:record_links].join(:projects, id: :right_id)
        names(links.where(left_kind: TASK, right_kind: PROJECT, left_id: OWNER), PROJECT_NAME)
      end

      def tag_names
        names(dataset.db[:task_tags].join(:tags, id: :tag_id).where(Sequel[:task_tags][:task_id] => OWNER), TAG_NAME)
      end
    end
  end
end
