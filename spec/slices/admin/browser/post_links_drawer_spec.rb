# frozen_string_literal: true

RSpec.describe "Admin post links drawer", type: :feature do
  let(:dead) { "https://bob.example/gone" }
  let(:post) { create(:post, :published, body: "intro\n\n[the note](#{dead})") }

  def drawer = find("dialog#post-links[open]")

  def selected
    evaluate_script("[document.activeElement.name, document.activeElement.selectionStart, " \
                    "document.activeElement.selectionEnd]")
  end

  before do
    sign_in_to_admin
    visit "/admin/posts/#{post.id}/edit"
    wait_for_stream
    find("button[data-dialog-open='post-links']").click
  end

  it "updates the open drawer when a check lands", :aggregate_failures do
    expect(drawer).to have_css(".pill", text: "not checked yet")

    Posts::Slice["relations.post_link_checks"].record(post_id: post.id, url: dead, reason: "404 Not Found",
                                                      at: Time.now)

    expect(drawer).to have_css(".pill.orange", text: "failing")
    expect(drawer).to have_css(".post-link-reason", text: "404 Not Found")
  end

  it "moves to the link in the body on Find in post", :aggregate_failures do
    drawer.find("[data-find-link='#{dead}']").click

    expect(page).to have_no_css("dialog#post-links[open]")
    at = post.body.index(dead)
    expect(selected).to eq(["post[body]", at, at + dead.length])
  end
end
