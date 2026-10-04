# frozen_string_literal: true

ROM::SQL.migration do
  kinds = { tasks: %w[carried someday], posts: %w[draft] }

  up do
    create_enum :attention_kind, %w[carried draft someday journal]

    create_table :attention_snoozes do
      primary_key :id
      column :kind, :attention_kind, null: false
      column :record_id, Integer
      column :ends_at, :timestamptz, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :attention_snoozes_record_check, Sequel.lit("(kind = 'journal') = (record_id IS NULL)")

      index %i[kind record_id], unique: true, nulls_distinct: false
    end

    run <<~SQL
      CREATE FUNCTION attention_snoozes_drop_record() RETURNS trigger AS $$
      BEGIN
        DELETE FROM attention_snoozes WHERE kind::text = ANY(TG_ARGV) AND record_id = OLD.id;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    kinds.each do |table, names|
      run <<~SQL
        CREATE TRIGGER #{table}_drop_attention_snoozes
          AFTER DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION attention_snoozes_drop_record(#{names.map { "'#{it}'" }.join(', ')});
      SQL
    end
  end

  down do
    kinds.each_key { |table| run "DROP TRIGGER #{table}_drop_attention_snoozes ON #{table};" }

    drop_table :attention_snoozes

    run "DROP FUNCTION attention_snoozes_drop_record();"

    drop_enum :attention_kind
  end
end
