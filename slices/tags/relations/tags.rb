# frozen_string_literal: true

module Tags
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      JOINS = Blog::DB::Plugins::Taggings::TABLES.to_h { |join, table| [table.fetch(:kind), join] }.freeze
      SUMMARY = Blog::Types::TagKind.values.map(&:to_sym).freeze
      ADMITTED = Blog::DB::Plugins::Taggings::ADMITTED

      schema :tags, infer: true

      def counts_by_kind(scope)
        JOINS.select { |_, join| ADMITTED.fetch(join).include?(scope) }.transform_values do |join|
          dataset.db[join].group_and_count(:tag_id).as_hash(:tag_id, :count)
        end
      end

      def counts_carrying(ids) = JOINS.slice(*SUMMARY).transform_values { dataset.db[it].where(tag_id: ids).count }

      def global = where(project_id: nil)

      def last_tag_of_rules(id)
        held = rules.where(id: rule_tags.where(tag_id: id).select(:task_rule_id))
        emptied = held.exclude(others(id).exists).exclude(rule_projects.where(task_rule_id: rule_id).exists)

        emptied.order(:pattern).select_map(:pattern)
      end

      def naming(text)
        return self if text.empty?
        return none if unmatchable?(text)

        where(Sequel.like(:name, like_pattern(text)))
      end

      def on_mail = where(id: mail_tags)

      def outside_mail
        held = JOINS.except(:messages).values.map { dataset.db[it].select(:tag_id) }.reduce(:union)

        exclude(id: mail_tags.except(held))
      end

      private

      def mail_tags = dataset.db[JOINS.fetch(:messages)].select(:tag_id)

      def others(id) = rule_tags.where(task_rule_id: rule_id).exclude(tag_id: id)

      def rule_id = Sequel[:task_rules][:id]

      def rule_projects = dataset.db[:task_rule_projects]

      def rule_tags = dataset.db[:task_rule_tags]

      def rules = dataset.db[:task_rules]
    end
  end
end
