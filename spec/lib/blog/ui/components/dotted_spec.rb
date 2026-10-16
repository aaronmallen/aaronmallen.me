# frozen_string_literal: true

RSpec.describe Blog::UI::Components::Dotted do
  def line(&) = described_class.new.call(&)

  it "puts a dot between the parts and keeps their markup" do
    html = line do |dotted|
      dotted.part { "one" }
      dotted.part { dotted.span { "two" } }
    end

    expect(html).to eq("one · <span>two</span>")
  end

  it "puts no dot around parts that render nothing" do
    html = line { |dotted| [nil, "one", nil, "two", nil].each { |part| dotted.part { part } } }

    expect(html).to eq("one · two")
  end

  it "renders nothing when no part renders" do
    expect(line { it.part { nil } }).to eq("")
  end

  it "escapes text parts" do
    expect(line { it.part { "<b>" } }).to eq("&lt;b&gt;")
  end
end
