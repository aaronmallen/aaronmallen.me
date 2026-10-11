# frozen_string_literal: true

ROM::SQL.migration do
  up do
    from(:service_connections).where(provider: "google_health").update(provider: "google")
  end

  down do
    from(:service_connections).where(provider: "google").update(provider: "google_health")
  end
end
