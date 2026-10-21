# frozen_string_literal: true

RSpec.describe Shares::Operations::ChangeCode do
  let(:share) { upload_share.value! }

  def change(code, owner = share) = described_class.new.call(owner, code:)

  def codes = Shares::Slice["relations.short_codes"].pluck(:code)

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  it "changes the code and frees the old one", :aggregate_failures do
    old = share.code

    code = change(" Resume-Me ").value!

    expect(code).to eq("resume-me")
    expect(codes).to eq(["resume-me"])
    expect(codes).not_to include(old)
  end

  it "keeps a short code as I typed it", :aggregate_failures do
    expect(change("cv").value!).to eq("cv")
    expect(codes).to eq(["cv"])
  end

  it "changes a short link's code" do
    link = Shares::Slice["operations.create_short_link"].call(destination: "https://example.com/talk").value!
    change("talk-now", link)

    expect(Shares::Slice["repos.short_link_queries"].find(link.id).code).to eq("talk-now")
  end

  it "refuses a code that breaks the format", :aggregate_failures do
    %w[-resume resume- re--sume re_sume résumé].each do |code|
      expect(change(code).failure).to eq([:invalid, { code: ["format"] }])
    end
    expect(codes).to eq([share.code])
  end

  it "refuses a blank code" do
    expect(change(" ").failure).to eq([:invalid, { code: ["blank"] }])
  end

  it "refuses a code another share holds" do
    other = upload_share.value!

    expect(change(other.code).failure).to eq([:invalid, { code: ["taken"] }])
  end

  it "answers not found when saving a missing share or link", :aggregate_failures do
    expect(Shares::Slice["operations.save_share"].call(0, code: "resume").failure).to eq(:not_found)
    expect(Shares::Slice["operations.save_short_link"].call(0, code: "talk").failure).to eq(:not_found)
  end

  it "leaves the database to refuse a bad code no contract checked" do
    expect { Shares::Slice["relations.short_codes"].command(:create).call(code: "Bad Code") }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end
end
