# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:mail_messages) { add_column :draft, :boolean, null: false, default: false }

    from(:mail_messages).where(mail_thread_id: from(:mail_threads).where(draft: true).select(:id)).update(draft: true)
  end

  down do
    alter_table(:mail_messages) { drop_column :draft }
  end
end
