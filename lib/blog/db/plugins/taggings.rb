# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module Taggings
        NAME = Sequel[:tags][:name]
        PRIVATE = Blog::Types::TagScope["private"]
        PUBLIC = Blog::Types::TagScope["public"]
        SCOPES = {
          post_tags: PUBLIC,
          project_tags: PUBLIC,
          journal_entry_tags: PRIVATE,
          task_tags: PRIVATE,
          decision_tags: PRIVATE,
          task_rule_tags: PRIVATE,
          message_tags: PRIVATE,
        }.freeze

        def self.apply(relation, owner_key:)
          relation.include(self)
          relation.define_method(:owner_key) { owner_key }
        end

        def add(ids, tag_ids)
          rows = Array(ids).product(tag_ids).map { |id, tag_id| { owner_key => id, tag_id: } }
          return Blog::Constants::EMPTY_ARRAY if rows.empty?

          dataset.insert_conflict.returning(owner_key).multi_insert(rows)
        end

        def for_owner(id) = where(owner_key => id)

        def holding_every(names)
          folded = names.map { it.to_s.downcase }.uniq
          owner = self[owner_key].qualified
          matched = unordered.join(:tag).where(NAME => folded)

          matched.group(owner).having(Sequel.function(:count, NAME).distinct => folded.length).select(owner)
        end

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
