# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module Tags
        def by_names(names) = where(name: names)

        def claim(names, scope:, project_id: nil, like: Blog::Constants::EMPTY_HASH)
          return Blog::Constants::EMPTY_HASH if names.empty?

          insert_missing(names, scope, project_id, like)

          in_scope(scope, project_id).by_names(names).to_a.to_h { [it[:name], it[:id]] }
        end

        def in_name_order = select_append(project_key).order(self[:name].asc)

        def in_scope(scope, project_id = nil) = project_id ? where(scope:, project_id:) : where(scope:)

        def next_color(scope:, project_id: nil) = least_used(color_counts(scope, project_id))

        private

        def color_counts(scope, project_id) = in_scope(scope, project_id).tally(:color, Blog::Types::TagColor.values)

        def insert_missing(names, scope, project_id, like)
          now = Time.now
          counts = color_counts(scope, project_id)

          names.each do |name|
            color, description = like.fetch(name, Blog::Constants::EMPTY_HASH).values_at(:color, :description)
            color ||= least_used(counts)
            counts[color] += 1

            upsert(name:, scope:, project_id:, color:, description:, created_at: now, updated_at: now)
          end
        end

        def least_used(counts)
          fewest = counts.values.min

          counts.select { |_, used| used == fewest }.keys.sample
        end

        def project_key
          key = dataset.db[:projects].where(id: Sequel[:tags][:project_id]).select(:key)

          ROM::SQL::Attribute[ROM::SQL::Types::String.optional].meta(sql_expr: key).as(:project_key)
        end
      end
    end
  end
end
