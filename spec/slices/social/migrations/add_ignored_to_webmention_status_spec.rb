# frozen_string_literal: true

RSpec.describe "Adding ignored to the webmention status enum", type: :migration do
  let(:gateway) { Social::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }

  def enum_values(type)
    db.from(:pg_enum).join(:pg_type, oid: :enumtypid).where(typname: type.to_s)
      .order(:enumsortorder).select_map(:enumlabel)
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_260_929_000_052)

  def status(mention) = db[:webmentions].where(id: mention.id).get(:status)

  describe "rolling back with an ignored mention on hand" do
    let!(:ignored) { create(:webmention, :ignored) }
    let!(:approved) { create(:webmention, :approved) }

    before { roll_back }

    it "takes ignored back off the statuses" do
      expect(enum_values(:webmention_status)).to eq(%w[pending approved spam])
    end

    it "keeps the ignored mention off the site as spam" do
      expect(status(ignored)).to eq("spam")
    end

    it "leaves the other mentions as they were" do
      expect(status(approved)).to eq("approved")
    end

    it "keeps the activity view reading approved mentions" do
      expect(db[:activities].where(type: "webmention").select_map(:source_id)).to eq([approved.id])
    end

    it "keeps pending as the default" do
      id = db[:webmentions].insert(post_id: approved.post_id, source_url: "https://ada.example/new", type: "mention")

      expect(db[:webmentions].where(id:).get(:status)).to eq("pending")
    end
  end

  it "adds ignored back before spam on the way up" do
    roll_back
    migrate

    expect(enum_values(:webmention_status)).to eq(%w[pending approved ignored spam])
  end
end
