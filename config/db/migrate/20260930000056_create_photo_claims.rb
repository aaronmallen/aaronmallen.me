# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :photo_owner, %w[post journal_entry task task_comment]

    create_table :photo_claims do
      foreign_key :photo_id, :photos, null: false, on_delete: :cascade
      column :owner, :photo_owner, null: false
      column :owner_id, :integer, null: false

      primary_key %i[owner owner_id photo_id]

      index :photo_id
    end
  end

  down do
    drop_table :photo_claims
    drop_enum :photo_owner
  end
end
