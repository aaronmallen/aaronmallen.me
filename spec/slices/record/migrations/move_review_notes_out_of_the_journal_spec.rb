# frozen_string_literal: true

RSpec.describe "Moving review notes out of the journal", type: :migration do
  let(:gateway) { Record::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:photo) { create(:photo) }
  let!(:entry) do
    attributes = { body: "good week", tags: %w[review health], created_at: written, updated_at: written }
    create(:journal_entry, entry_date: Date.new(2026, 9, 20), **attributes)
  end
  let!(:mine) { create(:journal_entry, entry_date: Date.new(2026, 9, 20), body: "walked the dog") }

  def claims = db[:photo_claims].select_map(%i[owner owner_id photo_id])

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def note = db[:review_notes].first

  def roll_back = migrate(20_261_004_000_404)

  def written = Time.utc(2026, 9, 16, 15, 30)

  before do
    roll_back
    db[:review_notes].insert(period: "week", starts_on: Date.new(2026, 9, 14), journal_entry_id: entry.id)
    db[:photo_claims].insert(owner: "journal_entry", owner_id: entry.id, photo_id: photo.id)
    migrate
  end

  it "keeps the note's text and when it was written" do
    expect(note.values_at(:period, :starts_on, :body, :created_at))
      .to eq(["week", Date.new(2026, 9, 14), "good week", written])
  end

  it "drops the note's entry from the journal and leaves mine" do
    expect(db[:journal_entries].select_map(%i[id body])).to eq([[mine.id, "walked the dog"]])
  end

  it "drops the note's entry tags" do
    expect(db[:journal_entry_tags].where(journal_entry_id: entry.id).count).to eq(0)
  end

  it "hands the note the photos its entry claimed" do
    expect(claims).to eq([["review_note", note[:id], photo.id]])
  end

  it "refuses a note with no text" do
    expect { db[:review_notes].insert(period: "week", starts_on: Date.new(2026, 9, 21)) }
      .to raise_error(Sequel::NotNullConstraintViolation)
  end

  describe "on the way down" do
    before { roll_back }

    def restored = db[:journal_entries].where(id: note[:journal_entry_id]).first

    it "writes the note back as an entry on the period's last day" do
      expect(restored.values_at(:entry_date, :body, :created_at)).to eq([Date.new(2026, 9, 20), "good week", written])
    end

    it "tags the entry review" do
      tags = db[:journal_entry_tags].join(:tags, id: :tag_id).where(journal_entry_id: restored[:id]).select_map(:name)

      expect(tags).to eq(%w[review])
    end

    it "hands the photos back to the entry" do
      expect(claims).to eq([["journal_entry", restored[:id], photo.id]])
    end
  end
end
