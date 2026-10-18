# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :artifact_type, %w[plan spec research handoff notes review postmortem other]

    create_table :artifacts do
      primary_key :id
      column :title, :non_blank_text, null: false
      column :type, :artifact_type, null: false
      column :tags, "text[]", null: false, default: Sequel.lit("'{}'")
      column :title_agent, :contributor_slug
      column :title_model, :contributor_slug
      column :version, Integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:artifacts_version_check) { version >= 0 }
      constraint :artifacts_title_length_check, Sequel.lit("char_length(title) <= 200")
      constraint :artifacts_title_author_check, Sequel.lit("num_nonnulls(title_agent, title_model) IN (0, 2)")
      constraint :artifacts_tags_check, Sequel.lit(<<~SQL)
        cardinality(tags) = 0 OR array_to_string(tags, ' ', '-') ~ '^[a-z0-9]+(-[a-z0-9]+)*( [a-z0-9]+(-[a-z0-9]+)*)*$'
      SQL

      index :type
      index :tags, type: :gin
    end

    create_table :artifact_versions do
      primary_key :id
      foreign_key :artifact_id, :artifacts, null: false, on_delete: :cascade
      column :number, Integer, null: false
      column :body, :non_blank_text, null: false
      column :note, :non_blank_text
      column :agent, :contributor_slug
      column :model, :contributor_slug
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :artifact_versions_body_length_check, Sequel.lit("char_length(body) <= 100000")
      constraint :artifact_versions_note_length_check, Sequel.lit("char_length(note) <= 200")
      constraint :artifact_versions_author_check, Sequel.lit("num_nonnulls(agent, model) IN (0, 2)")

      index %i[artifact_id number], unique: true
    end

    run <<~SQL
      CREATE FUNCTION artifact_versions_next_number() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        UPDATE artifacts SET version = version + 1, updated_at = CURRENT_TIMESTAMP
          WHERE id = NEW.artifact_id
          RETURNING version INTO NEW.number;

        RETURN NEW;
      END
      $$;

      CREATE TRIGGER artifact_versions_next_number BEFORE INSERT ON artifact_versions
        FOR EACH ROW EXECUTE FUNCTION artifact_versions_next_number();
    SQL

    %w[artifacts artifact_versions].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :artifact_versions
    drop_table :artifacts

    run "DROP FUNCTION artifact_versions_next_number();"

    drop_enum :artifact_type
  end
end
