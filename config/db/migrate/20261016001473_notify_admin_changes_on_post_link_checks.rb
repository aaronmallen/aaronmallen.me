# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE TRIGGER post_link_checks_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON post_link_checks
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER post_link_checks_notify_admin_change ON post_link_checks;
    SQL
  end
end
