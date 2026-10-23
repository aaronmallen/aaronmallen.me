# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "mise run test:map", type: :script do
  def map(files)
    Dir.mktmpdir do |root|
      { "spec/spec_helper.rb" => "", "spec/demo_spec.rb" => spec }.merge(files).each { write(root, *it) }
      output, status = Open3.capture2e(Hanami.app.root.join("scripts/test/map").to_s, root)
      maps = Dir.glob("features/rspec_map/*.yml", base: root)
      [output, status, YAML.load_file(File.join(root, "features/rspec_map/demo_spec.yml")), maps]
    end
  end

  def write(root, path, content)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), content)
  end

  let(:spec) do
    <<~RUBY
      RSpec.describe "Demo" do
        it("adds") { }
        it("drops") { }
      end
    RUBY
  end

  let(:feature) { "Feature: Demo\n\n  Scenario: Adding\n    Given nothing\n" }

  it "lists each example with neither scenario nor drop reason, and fails", :aggregate_failures do
    output, status, rows = map({})

    expect(status).not_to be_success
    expect(output).to include("Demo adds has no scenario or drop reason", "2 of 2 examples")
    expect(rows).to eq([{ "example" => "Demo adds" }, { "example" => "Demo drops" }])
  end

  it "passes once every example has a scenario or drop reason, keeping them", :aggregate_failures do
    rows = [{ "example" => "Demo adds", "scenario" => "demo.feature: Adding" },
            { "example" => "Demo drops", "drop" => "tests a gem" }]
    output, status, kept = map("features/demo.feature" => feature, "features/rspec_map/demo_spec.yml" => rows.to_yaml)

    expect(status).to be_success, output
    expect(kept).to eq(rows)
  end

  it "fails when a mapped scenario no longer exists", :aggregate_failures do
    rows = [{ "example" => "Demo adds", "scenario" => "demo.feature: Gone" },
            { "example" => "Demo drops", "drop" => "tests a gem" }]
    output, status, = map("features/demo.feature" => feature, "features/rspec_map/demo_spec.yml" => rows.to_yaml)

    expect(status).not_to be_success
    expect(output).to include("Demo adds maps to demo.feature: Gone, which no feature holds")
  end

  it "drops rows and files for examples RSpec no longer runs", :aggregate_failures do
    stale = [{ "example" => "Demo gone", "drop" => "old" }].to_yaml
    _, _, rows, maps = map("features/rspec_map/demo_spec.yml" => stale, "features/rspec_map/gone_spec.yml" => stale)

    expect(rows.map { it["example"] }).to eq(["Demo adds", "Demo drops"])
    expect(maps).to eq(["features/rspec_map/demo_spec.yml"])
  end
end
