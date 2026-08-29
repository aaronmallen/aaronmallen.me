# frozen_string_literal: true

RSpec.describe "Home sections", type: :feature do
  def box(selector)
    evaluate_script(<<~JS)
      (() => {
        const { bottom, right, top } = document.querySelector("#{selector}").getBoundingClientRect();
        return { bottom, right, top };
      })()
    JS
  end

  def style(selector, property) = evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")

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
    create(:post, :published, slug: "hello", summary: "One line and no more", title: "Hello")
    create(:project, name: "sai", tagline: "Terminal colors")
    visit "/"
  end

  it "names each section with a kicker and draws no heading over it", :aggregate_failures do
    expect(page.all(".sec > .sec-h > .kicker:first-child").map(&:text)).to eq(%w[WRITING PROJECTS])
    expect(page).to have_no_css(".sec > h2")
  end

  it "names the page with a heading it reads out and never draws", :aggregate_failures do
    expect(page).to have_css(".home > h1:first-child", exact_text: "Writing and projects")
    expect(style("h1", "position")).to eq("absolute")
    expect([style("h1", "width"), style("h1", "height")]).to eq(%w[1px 1px])
  end

  it "holds the page to the same column the archive uses" do
    expect(style(".home", "maxWidth")).to eq("1040px")
  end

  it "points each section header at its own list", :aggregate_failures do
    expect(page).to have_css(".sec:first-of-type .sec-h .sec-l[href='/writing']", exact_text: "All writing")
    expect(page).to have_css(".sec:last-of-type .sec-h .sec-l[href='/projects']", exact_text: "All projects")
  end

  it "sits the link on the kicker's row rather than under it", :aggregate_failures do
    kicker = box(".sec-h .kicker")
    link = box(".sec-h .sec-l")

    expect(style(".sec-h", "alignItems")).to eq("baseline")
    expect(link["top"]).to be < kicker["bottom"]
    expect(kicker["top"]).to be < link["bottom"]
  end

  it "pushes the link to the far edge of the section" do
    expect(box(".sec-h .sec-l")["right"]).to be_within(1).of(box(".sec-h")["right"])
  end

  it "reads the link as the same small mono line the entries use", :aggregate_failures do
    expect(style(".sec-l", "fontSize")).to eq(style(".entry-meta", "fontSize"))
    expect(style(".sec-l", "fontFamily")).to eq(style(".entry-meta", "fontFamily"))
    expect(style(".sec-l", "color")).to eq(token("ink-muted"))
    expect(style(".sec-l", "textDecorationLine")).to eq("none")
  end

  it "leaves the header's space under the row rather than under the kicker", :aggregate_failures do
    expect(style(".sec-h", "marginBottom")).to eq("16px")
    expect(style(".sec-h .kicker", "marginBottom")).to eq("0px")
  end

  it "sets the two sections 56px apart" do
    expect(style(".home > .sec + .sec", "marginTop")).to eq("56px")
  end
end
