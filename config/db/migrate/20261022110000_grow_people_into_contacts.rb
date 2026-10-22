# frozen_string_literal: true

ROM::SQL.migration do
  partial_date = "^([0-9]{4}|-)-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"
  texts = %i[
    name_prefix given_name middle_name family_name name_suffix
    phonetic_given_name phonetic_middle_name phonetic_family_name
    nickname file_as company job_title department notes
  ]
  handles = Sequel.function(:num_nonnulls, :mastodon_handle, :bluesky_handle)
  lists = %i[emails phones addresses websites chats dates relations custom_fields]

  weighted = Kernel.lambda do |weight, columns|
    text = columns.map { "coalesce(#{it}::text, '')" }.join(" || ' ' || ")
    "setweight(to_tsvector('english'::regconfig, #{text}), '#{weight}')"
  end

  rebuild_search = Kernel.lambda do |names, from, to|
    vector = "#{weighted.call('A', names)} || #{weighted.call('B', %w[key mastodon_handle bluesky_handle])}"

    <<~SQL
      DO $$
      DECLARE
        documents text := pg_get_viewdef('search_documents');
      BEGIN
        IF position('#{from}' IN documents) = 0 THEN
          RAISE EXCEPTION 'people title not found in the search_documents view';
        END IF;
        DROP VIEW search_documents;
        ALTER TABLE people DROP COLUMN search_vector;
        ALTER TABLE people ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (#{vector}) STORED;
        CREATE INDEX people_search_vector_index ON people USING gin (search_vector);
        EXECUTE 'CREATE VIEW search_documents AS ' || replace(documents, '#{from}', '#{to}');
      END
      $$;
    SQL
  end

  name_title = "(people.name)::text AS title"
  contact_title = "(COALESCE(people.name, people.company))::text AS title"

  up do
    run "CREATE DOMAIN partial_date AS text CHECK (VALUE ~ '#{partial_date}')"

    alter_table :people do
      set_column_allow_null :name
      set_column_allow_null :key
      drop_constraint :people_handles_check

      texts.each { add_column it, :non_blank_text }
      lists.each { add_column it, :jsonb, null: false, default: Sequel.lit("'[]'::jsonb") }
      add_column :birthday, :partial_date
      add_column :labels, "text[]", null: false, default: Sequel.lit("'{}'::text[]")
      add_column :starred, :boolean, null: false, default: false
      add_foreign_key :google_connection_id, :service_connections, on_delete: :set_null
      add_column :google_id, :non_blank_text

      add_constraint :people_name_check, Sequel.function(:num_nonnulls, :name, :company) > 0
      add_constraint :people_key_check, Sequel.|(Sequel.~(key: nil), handles => 0)
      lists.each { add_constraint :"people_#{it}_check", Sequel.function(:jsonb_typeof, it) => "array" }

      add_index %i[google_connection_id google_id], unique: true
    end

    run rebuild_search.call(%w[name company], name_title, contact_title)
  end

  down do
    run rebuild_search.call(%w[name], contact_title, name_title)

    alter_table :people do
      drop_index %i[google_connection_id google_id]
      drop_foreign_key :google_connection_id
      drop_constraint :people_name_check
      drop_constraint :people_key_check
      lists.each { drop_constraint :"people_#{it}_check" }

      (texts + lists + %i[birthday labels starred google_id]).each { drop_column it }

      add_constraint :people_handles_check, handles > 0
      set_column_not_null :key
      set_column_not_null :name
    end

    run "DROP DOMAIN partial_date"
  end
end
