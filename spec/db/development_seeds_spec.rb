# frozen_string_literal: true

require "tempfile"

RSpec.describe "Development seeds", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:seeds) { Hanami.app.root.join("config/db/seeds/development").glob("*.rb").sort.map(&:to_s) }

  it "loads every seed file" do
    seeds.each { load it }

    expect(db[:posts].count).to be_positive
  end

  it "fails when a seed file raises" do
    Tempfile.create(%w[broken .rb]) do |broken|
      broken.write("raise 'broken seed'\n")
      broken.flush

      expect { [*seeds, broken.path].each { load it } }.to raise_error(RuntimeError, "broken seed")
    end
  end
end
