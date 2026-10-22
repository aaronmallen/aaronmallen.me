# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :note_folders do
      primary_key :id
      foreign_key :parent_id, :note_folders, on_delete: :restrict
      column :name, :non_blank_text, null: false
      column :description, :text, null: false, default: ""
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :parent_id
    end

    create_table :notes do
      primary_key :id
      foreign_key :folder_id, :note_folders, on_delete: :restrict
      column :title, :non_blank_text, null: false
      column :body, :text, null: false, default: ""
      column :pinned, :boolean, null: false, default: false
      column :version, Integer, null: false, default: 1
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index Sequel.function(:lower, :title), unique: true, name: :notes_title_index
      index :folder_id
    end

    create_table :note_tags do
      foreign_key :note_id, :notes, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[note_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :cascade, name: :note_tags_tag_id_fkey
      constraint(:note_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end

    run <<~SQL
      CREATE FUNCTION notes_next_version() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        NEW.version := OLD.version + 1;

        RETURN NEW;
      END
      $$;

      CREATE TRIGGER notes_next_version BEFORE UPDATE ON notes
        FOR EACH ROW EXECUTE FUNCTION notes_next_version();

      CREATE FUNCTION note_folders_refuse_loop() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        IF EXISTS (
          WITH RECURSIVE ancestors(id) AS (
            SELECT NEW.parent_id
            UNION
            SELECT note_folders.parent_id FROM note_folders JOIN ancestors ON note_folders.id = ancestors.id
          )
          SELECT 1 FROM ancestors WHERE id = NEW.id
        ) THEN
          RAISE EXCEPTION 'a folder cannot sit inside itself'
            USING ERRCODE = 'check_violation', CONSTRAINT = 'note_folders_parent_loop';
        END IF;

        RETURN NEW;
      END
      $$;

      CREATE TRIGGER note_folders_refuse_loop BEFORE INSERT OR UPDATE OF parent_id ON note_folders
        FOR EACH ROW WHEN (NEW.parent_id IS NOT NULL) EXECUTE FUNCTION note_folders_refuse_loop();
    SQL

    %w[note_folders notes note_tags].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :note_tags
    drop_table :notes
    drop_table :note_folders

    run "DROP FUNCTION notes_next_version();"
    run "DROP FUNCTION note_folders_refuse_loop();"
  end
end
