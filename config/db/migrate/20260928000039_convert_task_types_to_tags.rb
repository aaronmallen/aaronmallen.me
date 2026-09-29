# frozen_string_literal: true

ROM::SQL.migration do
  colors = %w[mk-pink mk-green mk-blue mk-violet mk-sand mk-orange].freeze

  slug = Kernel.lambda do |type|
    name = type[:name].unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

    name.empty? ? "type-#{type[:id]}" : name
  end

  up do
    counts = colors.to_h { [it, 0] }.merge(from(:tags).group_and_count(:color).to_hash(:color, :count))

    from(:task_types).order(:position, :id).all.each do |type|
      name = slug.call(type)
      tag_id = from(:tags).where(name:).get(:id)

      unless tag_id
        color = counts.min_by { |_, used| used }.first
        counts[color] += 1
        tag_id = from(:tags).insert(name:, color:)
      end

      tagged = from(:tasks).where(task_type_id: type[:id]).select(:id, Sequel.cast(tag_id, Integer))
      from(:task_tags).insert_conflict.insert(%i[task_id tag_id], tagged)
    end

    alter_table(:tasks) { drop_foreign_key :task_type_id }
    drop_table :task_types
  end

  down do
    create_table :task_types do
      primary_key :id
      column :name, :non_blank_text, null: false
      column :color, :tag_color, null: false
      column :icon, :text
      column :position, :integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :task_types_position_check, Sequel.lit('"position" > 0')

      index Sequel.function(:lower, :name), unique: true, name: :task_types_name_key
    end

    alter_table :tasks do
      add_foreign_key :task_type_id, :task_types, on_delete: :restrict
      add_index :task_type_id
    end
  end
end
