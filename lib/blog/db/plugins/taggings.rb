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
          post_tags: { owner_key: :post_id, scope: PUBLIC, kind: :posts, record: "post" },
          project_tags: { owner_key: :project_id, scope: PUBLIC, kind: :projects },
          journal_entry_tags: {
            owner_key: :journal_entry_id, scope: PRIVATE, kind: :journal_entries, record: "journal_entry",
          },
          task_tags: { owner_key: :task_id, scope: PRIVATE, kind: :tasks },
          decision_tags: { owner_key: :decision_id, scope: PRIVATE, kind: :decisions, record: "decision" },
          task_rule_tags: { owner_key: :task_rule_id, scope: PRIVATE, kind: :task_rules },
          mail_thread_tags: { owner_key: :mail_thread_id, scope: PRIVATE, kind: :messages, record: "mail_thread" },
          note_tags: { owner_key: :note_id, scope: PRIVATE, kind: :notes, record: "note" },
        }.freeze
        LINKED_PROJECT = "project"
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

        def self.linked_projects(db, record, id)
          links = db[:record_links]
          left = links.where(left_kind: LINKED_PROJECT, right_kind: record, right_id: id).select(Sequel[:left_id])
          right = links.where(left_kind: record, left_id: id, right_kind: LINKED_PROJECT).select(Sequel[:right_id])

          left.union(right, all: true)
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

        def replace(id, tag_ids, scope = tag_scope, among: nil)
          held = among ? for_owner(id).where(tag_scope: among) : for_owner(id)
          held.exclude(tag_id: tag_ids).delete
          add(id, tag_ids - held.pluck(:tag_id), scope)
        end

        def retag(id, names, tags, project_id: nil)
          return retag_projects(id, names, tags, among: nil) if project_id.nil? && linked_projects(id).any?

          scope = scope_for(project_id)
          tag_ids = tags.claim(names, scope:, project_id:).values_at(*names)
          replace(id, tag_ids, scope, among: (PUBLIC if scope == PUBLIC))
          tag_ids
        end

        def retag_projects(id, names, tags, among: PROJECT)
          tag_ids = project_tag_ids(names, tags, projects_of(id))
          replace(id, tag_ids, PROJECT, among:)
          tag_ids
        end

        def scope_for(project_id) = project_id ? PROJECT : tag_scope

        def tag(ids, names, tags, project_id: nil)
          return add(ids, project_tag_ids(names, tags, [project_id]), PROJECT) if project_id

          Array(ids).group_by { linked_projects(it) }.flat_map do |projects, owners|
            next add(owners, tags.claim(names, scope: tag_scope).values) if projects.empty?

            add(owners, project_tag_ids(names, tags, projects), PROJECT)
          end
        end

        def tag_scope = SCOPES.fetch(schema.name.dataset)

        def untag(id, names, tags)
          scopes = tag_scope == PRIVATE ? ADMITTED.fetch(schema.name.dataset) : tag_scope
          for_owner(id).where(tag_id: tags.where(scope: scopes).by_names(names).select(:id).dataset).delete
        end

        private

        def held_tags(ids)
          owner = Taggings.owner(schema.name.dataset)
          found = dataset.unordered.join(:tags, id: :tag_id).where(owner => ids)

          found.select(owner.as(:owner), *%i[name color description].map { Sequel[:tags][it] }).to_a
        end

        def linked_projects(id) = tag_scope == PRIVATE ? projects_of(id) : Blog::Constants::EMPTY_ARRAY

        def project_tag_ids(names, tags, projects)
          held = tags.where(scope: PROJECT, project_id: projects).by_names(names).to_a
          missing = names - held.map { it[:name] }

          held.map { it[:id] } + projects.flat_map { tags.claim(missing, scope: PROJECT, project_id: it).values }
        end

        def projects_of(id)
          record = TABLES.fetch(schema.name.dataset)[:record]
          return Blog::Constants::EMPTY_ARRAY unless record

          Taggings.linked_projects(dataset.db, record, id).select_map(:left_id)
        end
      end
    end
  end
end
