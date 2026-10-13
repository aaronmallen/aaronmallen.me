# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "ALTER TYPE sign_in_outcome RENAME VALUE 'github_failed' TO 'provider_failed'"
    create_enum :sign_in_provider, %w[github google]

    alter_table :sign_ins do
      add_column :provider, :sign_in_provider, null: false, default: "github"
    end

    alter_table :sign_ins do
      set_column_default :provider, nil
    end
  end

  down do
    alter_table :sign_ins do
      drop_column :provider
    end

    drop_enum :sign_in_provider
    run "ALTER TYPE sign_in_outcome RENAME VALUE 'provider_failed' TO 'github_failed'"
  end
end
