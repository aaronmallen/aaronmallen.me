# frozen_string_literal: true

RSpec.describe Posts::Markdown::Document do
  describe "#headings" do
    it "lists the h2s in order with their ids" do
      document = described_class.new("# Title\n\n## The `config` file\n\n### Deeper\n\n## Wrap *up*")

      expect(document.headings)
        .to eq([{ id: "the-config-file", text: "The config file" }, { id: "wrap-up", text: "Wrap up" }])
    end

    it "gives a repeated h2 the numbered id its heading carries" do
      expect(described_class.new("## Setup\n\n## Setup").headings.map { it[:id] }).to eq(%w[setup setup-1])
    end

    it "keeps quotes and ampersands in the text" do
      expect(described_class.new(%(## "Fast" & loose)).headings).to eq([{ id: "fast--loose", text: %("Fast" & loose) }])
    end

    it "leaves out an empty h2" do
      expect(described_class.new("##\n\n## Next").headings).to eq([{ id: "next", text: "Next" }])
    end

    it "lists nothing for a body without h2s" do
      expect(described_class.new("plain text").headings).to eq([])
    end
  end
end
