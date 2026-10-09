# frozen_string_literal: true

RSpec.describe "Writing list", type: :feature do
  def box(selector)
    evaluate_script(<<~JS)
      (() => {
        const { bottom, left, right, top } = document.querySelector("#{selector}").getBoundingClientRect();
        return { bottom, left, right, top };
      })()
    JS
  end

  def list_width(width) = execute_script("document.querySelector('.entries').style.width = '#{width}px'")

  before do
    create(:tag, name: "ruby", color: "mk-violet")
    create(
      :post,
      :published,
      body: "word " * 440,
      published_at: Time.utc(2026, 9, 7, 12),
      slug: "hello",
      summary: "One line and no more",
      tags: %w[ruby],
      title: "Hello",
    )
    visit "/writing"
  end

  it "reads the date, the tag and the reading time down the meta column" do
    expect(page.find(".entry-meta").all(:xpath, "./*").map(&:text)).to eq(["Sep 7, 2026", "ruby", "2 min"])
  end

  it "sets the meta column beside the title on a list 720px wide" do
    list_width(720)

    expect(box(".entry-meta")["right"]).to be < box(".entry-title")["left"]
  end

  it "stacks the meta over the title on a narrower list, whatever the window" do
    list_width(719)

    expect(box(".entry-meta")["bottom"]).to be <= box(".entry-title")["top"]
  end

  it "links nothing in the row but the title" do
    expect(evaluate_script(<<~JS)).to be_nil
      (() => {
        const { left, top, width, height } = document.querySelector(".entry-blurb").getBoundingClientRect();
        return document.elementFromPoint(left + width / 2, top + height / 2).closest("a")?.href ?? null;
      })()
    JS
  end
end
