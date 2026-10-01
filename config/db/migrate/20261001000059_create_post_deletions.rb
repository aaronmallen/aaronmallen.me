# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :post_deletions do
      column :post_id, :integer, primary_key: true
      column :deleted_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    run <<~SQL
      CREATE FUNCTION posts_record_deletion() RETURNS trigger AS $$
      BEGIN
        INSERT INTO post_deletions (post_id) VALUES (OLD.id);

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER posts_record_deletion
        AFTER DELETE ON posts
        FOR EACH ROW WHEN (OLD.status = 'published')
        EXECUTE FUNCTION posts_record_deletion();
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER posts_record_deletion ON posts;
      DROP FUNCTION posts_record_deletion();
    SQL

    drop_table :post_deletions
  end
end
