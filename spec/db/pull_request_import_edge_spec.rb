# frozen_string_literal: true

RSpec.describe "Keeping the pull request import edge in sync_states", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:path) do
    Hanami.app.root.join("config/db/migrate/20261016002242_keep_the_pull_request_import_edge_in_sync_states.rb")
  end

  def edges = db.from(:sync_states).where(kind: "pull_requests").select_map(%i[sync repo synced_at])

  def migrate
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last.apply(db, :up)
  end

  it "starts the edge at the newest stored pull request, so the floor stays where it was" do
    newest = Time.utc(2026, 10, 1, 12)
    create(:pull_request, updated_at: newest - 60)
    create(:pull_request, updated_at: newest)

    migrate

    expect(edges).to eq([[nil, nil, newest]])
  end

  it "leaves no edge when no pull request is stored, so the next run reads from the start" do
    migrate

    expect(edges).to be_empty
  end
end
