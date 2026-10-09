# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :social_posts do
      add_column :connection_ids, "integer[]", null: false, default: Sequel.lit("'{}'::integer[]")
    end

    alter_table :social_post_deliveries do
      add_foreign_key :connection_id, :service_connections, on_delete: :set_null
      drop_index %i[social_post_id network]
      add_index %i[social_post_id connection_id], unique: true
    end
  end

  down do
    alter_table :social_post_deliveries do
      drop_index %i[social_post_id connection_id]
      drop_foreign_key :connection_id
      add_index %i[social_post_id network], unique: true
    end

    alter_table :social_posts do
      drop_column :connection_ids
    end
  end
end
