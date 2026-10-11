# frozen_string_literal: true

RSpec.describe Shares::Operations::ChangeShareCode do
  let(:share) { upload_share.value! }

  def change(code, id: share.id) = described_class.new.call(id, code:)

  def codes = Shares::Slice["relations.short_codes"].pluck(:code)

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  it "changes the code and frees the old one", :aggregate_failures do
    old = share.code

    expect(change(" Resume ").value!.code).to eq("resume")
    expect(codes).to eq(["resume"])
    expect(codes).not_to include(old)
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

  it "answers not found for a missing share" do
    expect(change("resume", id: 0).failure).to eq(:not_found)
  end

  it "leaves the database to refuse a bad code no contract checked" do
    expect { Shares::Slice["relations.short_codes"].command(:create).call(code: "Bad Code") }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end
end
