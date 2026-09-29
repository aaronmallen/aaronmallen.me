# frozen_string_literal: true

ROM::SQL.migration do
  public_joins = %i[post_tags project_tags].freeze
  private_joins = %i[journal_entry_tags task_tags].freeze

  up do
    create_enum :tag_scope, %w[public private]

    alter_table(:tags) { add_column :scope, :tag_scope }

    held = ->(joins) { joins.map { from(it).select(:tag_id) }.reduce(:union) }

    from(:tags).exclude(id: held.call(public_joins)).where(id: held.call(private_joins)).update(scope: "private")
    from(:tags).where(scope: nil).update(scope: "public")

    alter_table :tags do
      set_column_not_null :scope
      drop_constraint :tags_name_key
      add_unique_constraint %i[scope name], name: :tags_scope_name_key
    end

    from(:tags).where(scope: "public", id: held.call(private_joins)).all.each do |tag|
      copy = from(:tags).insert(tag.except(:id).merge(scope: "private"))

      private_joins.each { from(it).where(tag_id: tag[:id]).update(tag_id: copy) }
    end
  end

  down do
    from(:tags).where(scope: "private").all.each do |tag|
      original = from(:tags).where(scope: "public", name: tag[:name]).get(:id)
      next unless original

      private_joins.each { from(it).where(tag_id: tag[:id]).update(tag_id: original) }
      from(:tags).where(id: tag[:id]).delete
    end

    alter_table :tags do
      drop_constraint :tags_scope_name_key
      add_unique_constraint :name, name: :tags_name_key
      drop_column :scope
    end

    drop_enum :tag_scope
  end
end
