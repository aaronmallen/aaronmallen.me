# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :post_tag_removals do
      column :post_id, :integer, null: false
      column :tag_id, :integer, null: false
      column :removed_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      primary_key %i[post_id tag_id]
    end

    run <<~SQL
      CREATE FUNCTION post_tags_record_removal() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM posts WHERE id = OLD.post_id AND status = 'published') THEN
          INSERT INTO post_tag_removals (post_id, tag_id) VALUES (OLD.post_id, OLD.tag_id)
            ON CONFLICT (post_id, tag_id) DO UPDATE SET removed_at = EXCLUDED.removed_at;
        END IF;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER post_tags_record_removal
        AFTER DELETE ON post_tags
        FOR EACH ROW
        EXECUTE FUNCTION post_tags_record_removal();
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER post_tags_record_removal ON post_tags;
      DROP FUNCTION post_tags_record_removal();
    SQL

    drop_table :post_tag_removals
  end
end
