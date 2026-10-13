# frozen_string_literal: true

ROM::SQL.migration do
  up do
    from(:owner_identities).delete

    alter_table :owner_identities do
      drop_index %i[provider external_id]
      drop_column :provider
      drop_column :external_id
      add_column :email, :email_address, null: false
      add_index :email, unique: true
    end
  end

  down do
    from(:owner_identities).delete

    alter_table :owner_identities do
      drop_index :email
      drop_column :email
      add_column :provider, :non_blank_text, null: false
      add_column :external_id, :non_blank_text, null: false
      add_index %i[provider external_id], unique: true
    end
  end
end
