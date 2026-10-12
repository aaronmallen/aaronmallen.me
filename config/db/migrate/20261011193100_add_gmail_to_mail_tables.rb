# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :mail_category, %w[personal social promotions updates forums]

    alter_table :mail_accounts do
      add_column :address, :email_address
      add_column :history_id, :text

      add_index :address, unique: true
    end

    alter_table :mail_labels do
      add_column :gmail_id, :text, null: false

      add_index %i[mail_account_id gmail_id], unique: true
    end

    alter_table :mail_threads do
      add_column :gmail_id, :text
      add_column :starred, :boolean, null: false, default: false
      add_column :archived, :boolean, null: false, default: false
      add_column :trashed, :boolean, null: false, default: false
      add_column :sent, :boolean, null: false, default: false
      add_column :category, :mail_category

      add_index %i[mail_account_id gmail_id], unique: true
    end

    alter_table :mail_messages do
      add_column :gmail_id, :text
      add_column :from_name, :text
      add_column :html_body, :text
      set_column_allow_null :reply_to
      set_column_allow_null :body

      add_index %i[mail_thread_id gmail_id], unique: true
    end
  end

  down do
    from(:mail_accounts).where(provider: "gmail").delete

    alter_table :mail_messages do
      drop_index %i[mail_thread_id gmail_id]
      set_column_not_null :body
      set_column_not_null :reply_to
      drop_column :html_body
      drop_column :from_name
      drop_column :gmail_id
    end

    alter_table :mail_threads do
      drop_index %i[mail_account_id gmail_id]
      drop_column :category
      drop_column :sent
      drop_column :trashed
      drop_column :archived
      drop_column :starred
      drop_column :gmail_id
    end

    alter_table :mail_labels do
      drop_index %i[mail_account_id gmail_id]
      drop_column :gmail_id
    end

    alter_table :mail_accounts do
      drop_index :address
      drop_column :history_id
      drop_column :address
    end

    drop_enum :mail_category
  end
end
