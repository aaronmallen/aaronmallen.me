# frozen_string_literal: true

RSpec.describe "Writing list", type: :feature do
  let(:summary) { "One line and no more" }

  def hash_mark = evaluate_script("getComputedStyle(document.querySelector('.post-tag'), '::before').content")

  def style(selector, property)
    evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  def token(name)
    evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("span");
        probe.style.color = "var(--color-#{name})";
        document.body.append(probe);
        const value = getComputedStyle(probe).color;
        probe.remove();
        return value;
      })()
    JS
  end

  before do
    create(:tag, name: "ruby", color: "mk-violet")
    create(
      :post,
      :published,
      body: "word " * 440,
      published_at: Time.utc(2026, 9, 7, 12),
      slug: "hello",
      summary:,
      tags: %w[ruby],
      title: "Hello",
    )
    visit "/writing"
  end

  it "heads the list with a kicker, under a heading it never draws", :aggregate_failures do
    expect(page).to have_css(".writing > h1:first-child", exact_text: "Writing")
    expect(page).to have_css(".writing > .kicker", exact_text: "WRITING · NEWEST FIRST")
    expect(style(".writing > h1", "position")).to eq("absolute")
    expect([style(".writing > h1", "width"), style(".writing > h1", "height")]).to eq(%w[1px 1px])
  end

  it "holds the archive to the page column the design draws" do
    expect(style(".writing", "maxWidth")).to eq("1040px")
  end

  it "reads the date, the tag and the reading time down the meta column" do
    expect(page.find(".entry-meta").all(:xpath, "./*").map(&:text)).to eq(["Sep 7, 2026", "ruby", "2 min"])
  end

  it "draws the tag as coloured text, not a pill", :aggregate_failures do
    expect(hash_mark).to eq('"#"')
    expect(style(".post-tag", "borderTopWidth")).to eq("0px")
    expect(style(".post-tag", "paddingLeft")).to eq("0px")
    expect(style(".post-tag", "color")).to eq(token("mk-violet"))
  end

  it "shows the summary the post carries and nothing longer" do
    expect(page).to have_css(".entry-blurb", exact_text: summary)
  end
end
