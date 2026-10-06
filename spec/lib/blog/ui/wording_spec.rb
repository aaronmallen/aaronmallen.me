# frozen_string_literal: true

RSpec.describe Blog::UI::Wording do
  subject(:wording) { Class.new { include Blog::UI::Wording }.new }

  it "joins the parts with a middle dot" do
    expect(wording.dotted("one", "two", 3)).to eq("one · two · 3")
  end

  it "drops nil, empty and blank parts" do
    expect(wording.dotted(nil, "one", "", "  ", "two")).to eq("one · two")
  end

  it "answers an empty string when every part is blank" do
    expect(wording.dotted(nil, " ")).to eq("")
  end

  it "counts a value as written when it holds a character that is not space", :aggregate_failures do
    expect(wording.written?(" a ")).to be(true)
    expect(wording.written?(1)).to be(true)
  end

  it "counts nil, empty and blank values as not written", :aggregate_failures do
    expect(wording.written?(nil)).to be(false)
    expect(wording.written?("")).to be(false)
    expect(wording.written?(" \n\t")).to be(false)
  end
end
