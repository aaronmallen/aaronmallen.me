# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module Taggings
        NAME = Sequel[:tags][:name]
        PRIVATE = Blog::Types::TagScope["private"]
        PROJECT = Blog::Types::TagScope["project"]
        PUBLIC = Blog::Types::TagScope["public"]
        TABLES = {
          post_tags: { owner_key: :post_id, scope: PUBLIC, kind: :posts },
          project_tags: { owner_key: :project_id, scope: PUBLIC, kind: :projects },
          journal_entry_tags: { owner_key: :journal_entry_id, scope: PRIVATE, kind: :journal_entries },
          task_tags: { owner_key: :task_id, scope: PRIVATE, kind: :tasks },
          decision_tags: { owner_key: :decision_id, scope: PRIVATE, kind: :decisions },
          task_rule_tags: { owner_key: :task_rule_id, scope: PRIVATE, kind: :task_rules },
          mail_thread_tags: { owner_key: :mail_thread_id, scope: PRIVATE, kind: :messages },
          note_tags: { owner_key: :note_id, scope: PRIVATE, kind: :notes },
        }.freeze
        SCOPES = TABLES.transform_values { it.fetch(:scope) }.freeze
        ADMITTED = SCOPES.to_h { |join, scope| [join, join == :project_tags ? [scope] : [scope, PROJECT]] }.freeze

        module Tagged
          def self.apply(relation, through:)
            relation.define_method(:tagged) do |names|
              unmatchable?(names) ? none : where(id: Taggings.holding_every(dataset.db, through, names))
            end
          end
        end

        def self.holding_every(db, table, names)
          folded = names.map { it.to_s.downcase }.uniq
          owner = owner(table)
          matched = db[table].join(:tags, id: :tag_id).where(NAME => folded)

          matched.group(owner).having(Sequel.function(:count, NAME).distinct => folded.length).select(owner)
        end

        def self.owner(table) = Sequel[table][TABLES.fetch(table).fetch(:owner_key)]

        def add(ids, tag_ids, scope = tag_scope)
          rows = Array(ids).product(tag_ids).map { |id, tag_id| { owner_key => id, tag_id:, tag_scope: scope } }
          return Blog::Constants::EMPTY_ARRAY if rows.empty?

          dataset.insert_conflict.returning(owner_key).multi_insert(rows)
        end

        def carry(ids, tags, project_id: nil)
          held = held_tags(ids)
          scope = scope_for(project_id)
          like = held.to_h { [it[:name], it.slice(:color, :description)] }
          tag_ids = tags.claim(like.keys, scope:, project_id:, like:)

          held.group_by { it[:owner] }.each do |id, rows|
            names = rows.map { it[:name] }
            replace(id, tag_ids.values_at(*names), scope)
          end
        end

        def for_owner(id) = where(owner_key => id)

        def holding_every(names) = Taggings.holding_every(dataset.db, schema.name.dataset, names)

        def owner_key = TABLES.fetch(schema.name.dataset).fetch(:owner_key)

        def replace(id, tag_ids, scope = tag_scope)
          for_owner(id).exclude(tag_id: tag_ids).delete
          add(id, tag_ids - for_owner(id).pluck(:tag_id), scope)
        end

        def retag(id, names, tags, project_id: nil)
          scope = scope_for(project_id)
          tag_ids = tags.claim(names, scope:, project_id:).values_at(*names)
          replace(id, tag_ids, scope)
          tag_ids
        end

        def scope_for(project_id) = project_id ? PROJECT : tag_scope

        def tag(id, names, tags, project_id: nil)
          scope = scope_for(project_id)

          add(id, tags.claim(names, scope:, project_id:).values, scope)
        end

        def tag_scope = SCOPES.fetch(schema.name.dataset)

        def untag(id, names, tags)
          admitted = tags.where(scope: ADMITTED.fetch(schema.name.dataset)).by_names(names)

          for_owner(id).where(tag_id: admitted.pluck(:id)).delete
        end

        private

        def held_tags(ids)
          owner = Taggings.owner(schema.name.dataset)
          found = dataset.unordered.join(:tags, id: :tag_id).where(owner => ids)

          found.select(owner.as(:owner), *%i[name color description].map { Sequel[:tags][it] }).to_a
        end
      end
    end
  end
end
