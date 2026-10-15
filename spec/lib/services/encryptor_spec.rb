# frozen_string_literal: true

RSpec.describe Services::Encryptor do
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

  it "opens text sealed under previous_data_key" do
    sealed = described_class.new("o" * 64).seal(token)

    expect(described_class.new("n" * 64, "o" * 64).open(sealed)).to eq(token)
  end

  describe "#reseal" do
    subject(:encryptor) { described_class.new("n" * 64, "o" * 64) }

    it "leaves text sealed under data_key alone" do
      expect(encryptor.reseal(encryptor.seal(token))).to be_nil
    end

    it "seals text from previous_data_key under data_key alone" do
      resealed = encryptor.reseal(described_class.new("o" * 64).seal(token))

      expect(described_class.new("n" * 64).open(resealed)).to eq(token)
    end

    it "refuses text sealed under neither key" do
      expect { encryptor.reseal(described_class.new("k" * 64).seal(token)) }.to raise_error(described_class::Invalid)
    end
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
