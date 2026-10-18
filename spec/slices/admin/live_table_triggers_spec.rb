# frozen_string_literal: true

RSpec.describe "Admin live table triggers", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:triggered) do
    db.from(:pg_trigger).join(:pg_proc, oid: :tgfoid).join(:pg_class, oid: Sequel[:pg_trigger][:tgrelid])
      .where(proname: "notify_admin_change").select_map(:relname)
  end
  let(:lists) do
    paths = Dir[Hanami.app.root.join("slices/admin/ui/**/*.rb").to_s].select { File.read(it).include?("LIVE_TABLES =") }

    paths.to_h do |path|
      owner = Object.const_get(Admin::Slice.autoloader.cpath_expected_at(path))
      ["#{owner}::LIVE_TABLES", owner.const_get(:LIVE_TABLES, false)]
    end
  end

  it "finds the lists of the layout and the views" do
    layout = "Admin::UI::Layouts::Application::LIVE_TABLES"

    expect(lists).to include(layout, "Admin::UI::Views::Calendar::Show::LIVE_TABLES")
  end

  it "names only tables with an admin change trigger" do
    missing = lists.flat_map { |name, tables| (tables - triggered).map { "#{name} names #{it}" } }

    expect(missing).to be_empty
  end
end
