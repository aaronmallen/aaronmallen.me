# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :message_tags do
      foreign_key :message_id, :messages, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[message_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :cascade, name: :message_tags_tag_id_fkey
      constraint(:message_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end

    run <<~SQL
      CREATE TRIGGER message_tags_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON message_tags
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :message_tags
  end
end
