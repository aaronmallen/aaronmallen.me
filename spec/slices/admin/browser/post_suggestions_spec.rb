# frozen_string_literal: true

RSpec.describe "Admin post suggestions dialog", type: :feature do
  let(:article) { create(:post, :draft, body: "teh cat sat") }
  let(:suggestion_mutations) { Suggestions::Slice["repos.suggestion_mutations"] }

  def dialog = find("dialog#post-suggestions[open]")

  def toast_on_top?
    evaluate_script(<<~JS)
      (() => {
        const toast = document.querySelector(".toast");
        const box = toast.getBoundingClientRect();
        return toast.contains(document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2));
      })()
    JS
  end

  def typo(original, replacement) = { original:, replacement:, reason: "typo" }

  before do
    sign_in_to_admin
    suggestion_mutations.replace_for_post(article.id, [typo("teh", "the"), typo("sat", "slept")])
    visit "/admin/posts/#{article.id}/edit"
    click_button "Review"
  end

  it "stays open with one suggestion left after an Accept", :aggregate_failures do
    dialog.click_button("Accept", exact: true, match: :first)

    expect(page).to have_css(".toast", text: "Suggestion applied")
    expect(dialog).to have_css(".sg-edit", count: 1)
  end

  it "stays open with one suggestion left after a Reject" do
    dialog.click_button("Reject", exact: true, match: :first)

    expect(dialog).to have_css(".sg-edit", count: 1)
  end

  it "shows the toast above the open dialog" do
    dialog.click_button("Accept", exact: true, match: :first)
    page.assert_selector(".toast", text: "Suggestion applied")

    expect(toast_on_top?).to be(true)
  end

  it "closes with the banner once the last suggestion is settled", :aggregate_failures do
    dialog.click_button("Accept", exact: true, match: :first)
    expect(dialog).to have_css(".sg-edit", count: 1)
    dialog.click_button("Accept", exact: true, match: :first)

    expect(page).to have_no_css("dialog#post-suggestions", visible: :all)
    expect(page).to have_no_css(".post-banner")
  end

  it "closes after Accept all", :aggregate_failures do
    dialog.click_button("Accept all")

    expect(page).to have_css(".toast", text: "2 suggestions applied")
    expect(page).to have_no_css("dialog[open]")
  end
end
