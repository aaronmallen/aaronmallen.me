# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module Taggings
        NAME = Sequel[:tags][:name]
        PRIVATE = Blog::Types::TagScope["private"]
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

        def add(ids, tag_ids)
          rows = Array(ids).product(tag_ids).map { |id, tag_id| { owner_key => id, tag_id: } }
          return Blog::Constants::EMPTY_ARRAY if rows.empty?

          dataset.insert_conflict.returning(owner_key).multi_insert(rows)
        end

        def for_owner(id) = where(owner_key => id)

        def holding_every(names) = Taggings.holding_every(dataset.db, schema.name.dataset, names)

        def owner_key = TABLES.fetch(schema.name.dataset).fetch(:owner_key)

        def replace(id, tag_ids)
          for_owner(id).exclude(tag_id: tag_ids).delete
          add(id, tag_ids - for_owner(id).pluck(:tag_id))
        end

        def retag(id, names, tags)
          tag_ids = tags.claim(names, scope: tag_scope).values_at(*names)
          replace(id, tag_ids)
          tag_ids
        end

        def tag(id, names, tags) = add(id, tags.claim(names, scope: tag_scope).values)

        def tag_scope = SCOPES.fetch(schema.name.dataset)

        def untag(id, names, tags)
          for_owner(id).where(tag_id: tags.in_scope(tag_scope).by_names(names).pluck(:id)).delete
        end
      end
    end
  end
end
