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
end
