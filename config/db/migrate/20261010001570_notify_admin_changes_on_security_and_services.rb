# frozen_string_literal: true

ROM::SQL.migration do
  tables = %w[service_apps service_connections sign_ins]

  up do
    tables.each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    tables.each do |table|
      run <<~SQL
        DROP TRIGGER #{table}_notify_admin_change ON #{table};
      SQL
    end
  end
end
