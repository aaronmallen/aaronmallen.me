# frozen_string_literal: true

RSpec.describe "Creating the spam senders", type: :migration do
  let(:gateway) { Contact::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:hour) { 60 * 60 }

  def flagged = db[:spam_senders].order(:reply_to).select_map(:reply_to)

  def message(reply_to, status, marked_at: Time.now - hour)
    db[:messages].insert(
      reply_to:, status:, subject: "Hello", body: "Hi", visitor_hash: "a" * 64, received_at: Time.now - (2 * hour),
      created_at: Time.now - (2 * hour), updated_at: marked_at, marked_spam_at: (marked_at if status == "spam"),
    )
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_261_001_000_061)

  before { roll_back }

  it "flags the lowercased address of every spam message" do
    message("Ada@Example.com", "spam")
    message("ada@example.com", "spam")
    migrate

    expect(flagged).to eq(["ada@example.com"])
  end

  it "leaves an address alone with no spam message" do
    message("grace@example.com", "read")
    message("linus@example.com", "unread")
    migrate

    expect(flagged).to be_empty
  end

  it "leaves an address alone once a message from it was marked after its spam" do
    message("ada@example.com", "spam", marked_at: Time.now - hour)
    message("ADA@example.com", "read", marked_at: Time.now - 60)
    migrate

    expect(flagged).to be_empty
  end

  it "flags an address whose message was marked before its spam" do
    message("ada@example.com", "read", marked_at: Time.now - hour)
    message("ada@example.com", "spam", marked_at: Time.now - 60)
    migrate

    expect(flagged).to eq(["ada@example.com"])
  end

  it "flags an address whose newer message arrived unread and was never marked" do
    message("ada@example.com", "spam", marked_at: Time.now - hour)
    db[:messages].insert(reply_to: "ada@example.com", subject: "Again", body: "Hi", visitor_hash: "b" * 64)
    migrate

    expect(flagged).to eq(["ada@example.com"])
  end

  it "refuses an address with capitals" do
    migrate

    expect { db[:spam_senders].insert(reply_to: "Ada@example.com") }
      .to raise_error(Sequel::CheckConstraintViolation, /spam_senders_reply_to_lower_check/)
  end

  it "drops the table on the way down" do
    migrate
    roll_back

    expect(db.table_exists?(:spam_senders)).to be(false)
  end
end
