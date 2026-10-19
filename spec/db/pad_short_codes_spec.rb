# frozen_string_literal: true

RSpec.describe "Padding short codes to 8 characters", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:migration) do
    path = Hanami.app.root.join("config/db/migrate/20261019160000_pad_short_codes.rb")
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last
  end

  let(:olds) { %w[abc xyz talk-to-me abcdefghjkmnpqrs] }

  def code(id) = db[:short_codes].where(id:).get(:code)

  def resolved(path) = Shares::Slice["relations.short_codes"].resolved_id(path).get(:id)

  before { migration.apply(db, :down) }

  context "when every padded code keeps its record" do
    let!(:ids) { olds.map { db[:short_codes].insert(code: it) } }

    before { migration.apply(db, :up) }

    it "pads short codes to 8 and keeps their start", :aggregate_failures do
      ids.first(2).zip(olds) do |id, old|
        expect(code(id).length).to eq(8)
        expect(code(id)).to start_with(old)
      end
    end

    it "leaves codes of 8 or more alone" do
      expect(ids.last(2).map { code(it) }).to eq(olds.last(2))
    end

    it "opens each record at its old code" do
      expect(olds.map { resolved(it) }).to eq(ids)
    end

    it "refuses a code shorter than 8" do
      expect { db[:short_codes].insert(code: "abcdefg") }.to raise_error(Sequel::CheckConstraintViolation)
    end
  end

  it "raises when a padded code would take an old code from its record", :aggregate_failures do
    db[:short_codes].insert(code: "abc")
    db[:short_codes].insert(code: "abcd")
    allow(SecureRandom).to receive(:rand).and_return(3, 3, 3, 3, 3, 0)

    expect { migration.apply(db, :up) }.to raise_error(RuntimeError, /abcd/)
    expect(db[:short_codes].select_map(:code)).to contain_exactly("abc", "abcd")
  end
end
