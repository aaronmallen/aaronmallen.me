# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :mail_labels do
      drop_index %i[mail_account_id name]
      add_unique_constraint %i[mail_account_id name], name: :mail_labels_mail_account_id_name_key,
                                                      deferrable: :immediate
    end
  end

  down do
    alter_table :mail_labels do
      drop_constraint :mail_labels_mail_account_id_name_key
      add_index %i[mail_account_id name], unique: true
    end
  end
end
