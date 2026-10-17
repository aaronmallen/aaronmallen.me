# frozen_string_literal: true

module Tasks
  module Relations
    class TaskLinks < Blog::DB::Relation
      ANY = ROM::SQL::Attribute[ROM::Types::Any]
      PARTNERS = Sequel[:partners]
      PARTNER = %i[id number title status list].to_h { [it, PARTNERS[it]] }.freeze

      schema :task_links, infer: true do
        associations do
          belongs_to :tasks, as: :from_task, foreign_key: :from_task_id, view: :labelled
          belongs_to :tasks, as: :to_task, foreign_key: :to_task_id, view: :labelled
        end
      end

      def between(one, two)
        ends = [one, two].minmax

        where(
          Sequel.function(:least, :from_task_id, :to_task_id) => ends.first,
          Sequel.function(:greatest, :from_task_id, :to_task_id) => ends.last,
        )
      end

      def from_partners = partnered(:from_task_id)

      def partner_ids(id)
        where(from_task_id: id).select(:to_task_id).union(where(to_task_id: id).select(:from_task_id))
      end

      def partner_label
        key = dataset.db[:projects].where(Sequel[:projects][:id] => PARTNERS[:project_id]).select(:key)

        Sequel.function(:concat_ws, "-", key, PARTNERS[:number])
      end

      def partnered(side)
        joined = new(dataset.join(Sequel[:tasks].as(:partners), PARTNERS[:id] => self[side].qualified))
        columns = { **PARTNER, label: partner_label }

        joined.select_append(*columns.map { |name, expr| ANY.meta(sql_expr: expr).as(:"partner_#{name}") })
      end

      def to_partners = partnered(:to_task_id)
    end
  end
end
