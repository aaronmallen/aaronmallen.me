# frozen_string_literal: true

RSpec.describe Markdown::WikiLinks do
  describe ".titles" do
    it "reads each title once, trimmed, in the order written, whatever its case" do
      body = "[[ Ruby ]], [[Rails|the framework]] and [[ruby]]"

      expect(described_class.titles(body)).to eq(%w[Ruby Rails])
    end

    it "skips a blank link and one split across lines" do
      expect(described_class.titles("[[ ]] and [[Two\nlines]]")).to be_empty
    end
  end

  describe ".plain" do
    it "keeps each link's text and drops the Markdown marks around it" do
      line = "- **See** [[Ruby]] and [[Rails|the `framework`]]\n"

      expect(described_class.plain(line)).to eq("See Ruby and the framework")
    end
  end

  describe ".rewrite" do
    it "renames every link to the old title, whatever its case, and keeps the link text" do
      body = "[[Ruby]], [[ ruby |the language]] and [[Rails]]"

      expect(described_class.rewrite(body, "Ruby", "Crystal"))
        .to eq("[[Crystal]], [[Crystal|the language]] and [[Rails]]")
    end
  end

  describe ".link" do
    def linked(html) = described_class.link(html) { |title| ["a", { "href" => "/#{title}" }] }

    it "swaps each link for the element the block names, with the link text inside" do
      expect(linked("<p>See [[Ruby|the language]] &amp; [[Rails]].</p>"))
        .to eq(%(<p>See <a href="/Ruby">the language</a> &amp; <a href="/Rails">Rails</a>.</p>))
    end

    it "leaves links inside code alone" do
      expect(linked("<p><code>[[Ruby]]</code></p>")).to eq("<p><code>[[Ruby]]</code></p>")
    end

    it "keeps what the title holds inside the attribute and the text", :aggregate_failures do
      link = Nokogiri::HTML5.fragment(linked(%(<p>[[x" onclick="y &lt;b&gt;]]</p>))).at_css("a")

      expect(link.attributes.keys).to eq(%w[href])
      expect(link.text).to eq(%(x" onclick="y <b>))
    end
  end
end
