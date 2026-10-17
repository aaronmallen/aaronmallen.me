# frozen_string_literal: true

RSpec.describe Shares::Operations::CreateShortLink do
  def create(**params) = described_class.new.call({ destination: "https://example.com/talk" }.merge(params))

  it "makes a link with a random three character code", :aggregate_failures do
    link = create.value!

    expect(link.code).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{3}\z/)
    expect(link.destination).to eq("https://example.com/talk")
    expect(link.click_count).to eq(0)
  end

  it "takes the one three character code left free" do
    codes = Shares::Helpers::Code::ALPHABET.repeated_permutation(3).map(&:join) - ["xyz"]
    Shares::Slice["relations.short_codes"].dataset.import([:code], codes)

    expect(create.value!.code).to eq("xyz")
  end

  it "moves to four characters once every three character code is taken" do
    codes = Shares::Helpers::Code::ALPHABET.repeated_permutation(3).map(&:join)
    Shares::Slice["relations.short_codes"].dataset.import([:code], codes)

    expect(create.value!.code).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{4}\z/)
  end

  it "counts no typed code outside the alphabet toward a full length" do
    codes = Shares::Helpers::Code::ALPHABET.repeated_permutation(3).map(&:join) - ["xyz"] + ["abl"]
    Shares::Slice["relations.short_codes"].dataset.import([:code], codes)

    expect(create.value!.code).to eq("xyz")
  end

  it "makes a link with the code and title I give", :aggregate_failures do
    link = create(code: " Talk ", title: " My talk ").value!

    expect(link.code).to eq("talk")
    expect(link.title).to eq("My talk")
  end

  it "refuses a code a share holds" do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    share = upload_share.value!

    expect(create(code: share.code).failure).to eq([:invalid, { code: ["taken"] }])
  end

  it "refuses a code that breaks the format" do
    %w[-talk talk- ta--lk ta_lk tålk].each do |code|
      expect(create(code:).failure).to eq([:invalid, { code: ["format"] }])
    end
  end

  it "refuses a link that is not http or https", :aggregate_failures do
    ["ftp://example.com", "javascript:alert(1)", "example.com", "mailto:me@example.com"].each do |destination|
      expect(create(destination:).failure).to eq([:invalid, { destination: ["format"] }])
    end
    [" ", nil].each { expect(create(destination: it).failure).to eq([:invalid, { destination: ["blank"] }]) }
    expect(Shares::Slice["relations.short_links"].count).to eq(0)
  end

  it "takes an http link" do
    expect(create(destination: "http://example.com").value!.destination).to eq("http://example.com")
  end

  it "leaves the database to refuse a link no contract checked" do
    code = Shares::Slice["relations.short_codes"].command(:create).call(code: "talk")

    expect do
      Shares::Slice["relations.short_links"].command(:create).call(short_code_id: code[:id], destination: "ftp://x")
    end.to raise_error(ROM::SQL::CheckConstraintError)
  end

  it "leaves the database to refuse a code a share or link holds" do
    create(code: "talk")

    expect { Shares::Slice["relations.short_codes"].command(:create).call(code: "talk") }
      .to raise_error(ROM::SQL::UniqueConstraintError)
  end
end
