# frozen_string_literal: true

RSpec.describe Blog::Encryptor do
  subject(:encryptor) { described_class.new }

  let(:token) { "gho_ünïcode-token" }

  it "opens what it seals" do
    expect(encryptor.open(encryptor.seal(token))).to eq(token)
  end

  it "keeps the text out of what it seals" do
    expect(encryptor.seal(token)).not_to include("gho_")
  end

  it "seals the same text differently each time" do
    expect(encryptor.seal(token)).not_to eq(encryptor.seal(token))
  end

  it "keys itself from data_key" do
    expect(described_class.new(Hanami.app.settings.data_key).open(encryptor.seal(token))).to eq(token)
  end

  it "refuses text sealed under another key" do
    sealed = described_class.new("k" * 64).seal(token)

    expect { encryptor.open(sealed) }.to raise_error(described_class::Invalid)
  end

  it "refuses tampered text", :aggregate_failures do
    raw = encryptor.seal(token).unpack1("m0")

    [0, 12, raw.bytesize - 1].each do |index|
      tampered = raw.dup.tap { it.setbyte(index, it.getbyte(index) ^ 1) }
      expect { encryptor.open([tampered].pack("m0")) }.to raise_error(described_class::Invalid)
    end
  end

  it "refuses text that is not sealed", :aggregate_failures do
    [nil, "", "not base64!", ["short"].pack("m0")].each do |text|
      expect { encryptor.open(text) }.to raise_error(described_class::Invalid)
    end
  end
end
