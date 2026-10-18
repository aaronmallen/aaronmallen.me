# frozen_string_literal: true

RSpec.describe Blog::Types do
  describe "TagField" do
    it "writes names and tag structs as the field TagList reads back", :aggregate_failures do
      field = described_class::TagField[["ruby", Struct.new(:name).new("hanami")]]

      expect(field).to eq("ruby, hanami")
      expect(described_class::TagList[field]).to eq(%w[ruby hanami])
    end

    it "writes an empty field for no tags" do
      expect(described_class::TagField[nil]).to eq("")
    end
  end

  describe "TagList" do
    it "takes an array as given, without splitting a name on commas" do
      expect(described_class::TagList[[" Ruby ", "a, b", "", "ruby"]]).to eq(["ruby", "a, b"])
    end

    it "splits a form field and reads nothing as no tags", :aggregate_failures do
      expect(described_class::TagList["Ruby, hanami,, ruby"]).to eq(%w[ruby hanami])
      expect(described_class::TagList[nil]).to eq([])
    end
  end

  describe "Checkbox" do
    it "reads JSON true and a ticked form box as true, and anything else as false", :aggregate_failures do
      expect([true, "1"].map { described_class::Checkbox[it] }).to eq([true, true])
      expect([false, "0", nil, "true"].map { described_class::Checkbox[it] }).to eq([false, false, false, false])
    end
  end
end
