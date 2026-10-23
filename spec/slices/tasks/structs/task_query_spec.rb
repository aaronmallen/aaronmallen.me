# frozen_string_literal: true

RSpec.describe Tasks::Structs::TaskQuery do
  def parsed(text) = described_class.parse(text)

  def term(key, value, negated: false) = described_class::Term.new(key:, value:, negated:)

  it "reads each alias as its qualifier, in any case" do
    expect(parsed("L:Bug,Docs COL:Ready is:DOING").terms)
      .to eq([term("label", "bug,docs"), term("column", "ready"), term("is", "doing")])
  end

  it "reads a - before a qualifier as negated" do
    expect(parsed("-label:bug -no:label").terms).to eq([term("label", "bug", negated: true),
                                                        term("no", "label", negated: true)])
  end

  it "reads a quoted value or phrase whole" do
    expect(parsed('col:"in progress" "fix the feed" pod-1').terms)
      .to eq([term("column", "in_progress"), term(nil, "fix the feed"), term(nil, "pod-1")])
  end

  it "keeps the words as texts" do
    expect(parsed("fix is:open #12").texts).to eq(%w[fix #12])
  end

  it "ignores an unknown qualifier or value, as written" do
    ignored = ["author:me", "-is:soon", "no:tags", "column:later", "label:,"]

    expect(parsed("#{ignored.join(' ')} is:open")).to have_attributes(terms: [term("is", "open")], ignored:)
  end

  it "drops a NUL" do
    expect(parsed("fi\0x").texts).to eq(%w[fix])
  end

  it "reads nothing from nil" do
    expect(parsed(nil)).to have_attributes(terms: [], ignored: [])
  end
end
