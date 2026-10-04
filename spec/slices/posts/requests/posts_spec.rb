# frozen_string_literal: true

RSpec.describe "Posts", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }

  def publish(slug, published_at: Time.now - 60, **)
    create(:post, :published, slug:, title: slug.capitalize, published_at:, **)
  end

  describe "the blurb on the writing page" do
    it "joins the lines of a wrapped first paragraph with a space" do
      publish("hello", body: "the first line\nwraps onto the next")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "the first line wraps onto the next")
    end

    it "leaves the blurb out when the first paragraph holds only an image with no alt text" do
      publish("hello", body: "![](https://example.com/a.png)\n\nthe second part")
      get "/writing"

      expect(page).to have_css(".entry-title", text: "Hello").and have_no_css(".entry-blurb")
    end
  end

  describe "the pager on two posts published at the same time" do
    let(:at) { Time.now.round - 60 }

    before { %w[first second].each { publish(it, published_at: at) } }

    it "links the older id as previous", :aggregate_failures do
      get "/writing/second"

      expect(page).to have_css(".post-pager a[rel='prev'][href='/writing/first']")
      expect(page).to have_no_css(".post-pager a[rel='next']")
    end

    it "links the newer id as next", :aggregate_failures do
      get "/writing/first"

      expect(page).to have_css(".post-pager a[rel='next'][href='/writing/second']")
      expect(page).to have_no_css(".post-pager a[rel='prev']")
    end
  end

  describe "saving from the admin editor" do
    let(:i18n) { Admin::Slice["i18n"] }

    before { sign_in_to_admin }

    def field_error = page.find(".field-error").text

    def save(path = "/admin/posts", **fields)
      post path, _csrf_token: admin_csrf_token, intent: "draft", post: fields
    end

    def save_going_live(post, **fields)
      going_live = Data.define(:id, :status, :published_at).new(post.id, "scheduled", post.published_at)
      allow(post_repo).to receive(:by_id_for_update).and_return(going_live)
      replace_component("repos.post_repo", post_repo)
      save("/admin/posts/#{post.id}", **fields)
    end

    def slug_error(code) = i18n.t(code, scope: "ui.components.posts.field_error.slug")

    it "refuses a blank slug when the title has no letter or number", :aggregate_failures do
      save(title: "!!!", slug: "")

      expect(last_response.status).to eq(422)
      expect(field_error).to eq(slug_error("blank"))
      expect(post_repo.all).to be_empty
    end

    it "turns the published slug lock into a slug error when a post goes live mid-edit", :aggregate_failures do
      published = publish("hello")
      save_going_live(published, title: "Hello", slug: "goodbye")

      expect(field_error).to eq(slug_error("locked"))
      expect(post_repo.by_id(published.id)).to have_attributes(slug: "hello", status: "published")
    end

    it "raises for a constraint no form can break" do
      allow(post_repo).to(receive(:create).and_wrap_original do |create, attributes|
        create.call(attributes.merge(status: "scheduled", published_at: nil))
      end)
      replace_component("repos.post_repo", post_repo)

      expect { save(title: "Hello", slug: "hello") }.to raise_error(ROM::SQL::CheckConstraintError)
    end
  end
end
