# frozen_string_literal: true

RSpec.describe "Home sections", type: :feature do
  def box(selector)
    evaluate_script(<<~JS)
      (() => {
        const { bottom, left, right, top } = document.querySelector("#{selector}").getBoundingClientRect();
        return { bottom, left, right, top };
      })()
    JS
  end

  before do
    create(:post, :published, slug: "hello", summary: "One line and no more", title: "Hello")
    create(:project, name: "sai", tagline: "Terminal colors")
    visit "/"
  end

  it "sits the link on the kicker's row rather than under it", :aggregate_failures do
    kicker = box(".sh .kicker")
    link = box(".sh .sec-l")

    expect(link["top"]).to be < kicker["bottom"]
    expect(kicker["top"]).to be < link["bottom"]
  end

  it "sets projects beside writing from 900px", :aggregate_failures do
    page.current_window.resize_to(1280, 800)

    expect(box(".g > section:last-child")["left"]).to be > box(".g > section:first-child")["right"]
    expect(box(".g > section:last-child")["right"] - box(".g > section:last-child")["left"]).to be >= 300
  end

  it "stacks projects under writing below 900px" do
    page.current_window.resize_to(800, 800)

    expect(box(".g > section:last-child")["top"]).to be > box(".g > section:first-child")["bottom"]
  end

  it "runs the main the full width of the window" do
    expect(evaluate_script("document.querySelector('main').getBoundingClientRect().width"))
      .to be_within(1).of(evaluate_script("document.documentElement.clientWidth"))
  end

  it "sets the body type at 17px on 1.55" do
    expect(evaluate_script("(({ fontSize, lineHeight }) => [fontSize, lineHeight])(getComputedStyle(document.body))"))
      .to eq(["17px", "26.35px"])
  end

  it "pushes the link to the far edge of the section" do
    expect(box(".sh .sec-l")["right"]).to be_within(1).of(box(".sh")["right"])
  end
end
