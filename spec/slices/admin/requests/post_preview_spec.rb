# frozen_string_literal: true

RSpec.describe "Admin post preview", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def preview(token: admin_csrf_token, **fields)
    post "/admin/posts/preview", { post: fields }, { "HTTP_X_CSRF_TOKEN" => token }
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers with the preview and no layout", :aggregate_failures do
      preview(title: "Hello", body: "one two")

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with("text/html")
      expect(last_response.body).to start_with("<h2")
      expect(last_response.body).not_to include("<main")
    end

    it "renders the trimmed title" do
      preview(title: "  Hello  ")

      expect(page).to have_css("h2.preview-title", exact_text: "Hello")
    end

    it "leaves the title out when it is blank" do
      preview(title: " ", body: "one")

      expect(page).to have_no_css(".preview-title")
    end

    it "renders the tags as the article does, trimmed and without repeats" do
      preview(tags: " ruby, hanami,, ruby ")

      expect(page.all(".post-meta a.post-tag").map { [it.text, it[:href]] })
        .to eq([%w[ruby /writing/tags/ruby], %w[hanami /writing/tags/hanami]])
    end

    it "renders the read time" do
      preview(body: (["word"] * 700).join(" "))

      expect(page).to have_css(".post-meta span", exact_text: "3 min read")
    end

    it "dates the post by its publish time in Chicago" do
      preview(publish_at: "2030-09-07T22:30")

      expect(page).to have_css(".post-meta time[datetime='2030-09-07T22:30:00-05:00']", exact_text: "Sep 7, 2030")
    end

    [["", "no publish time"], ["soon", "a publish time it can't read"], ["2027-03-14T02:30", "a skipped time"]]
      .each do |(publish_at, description)|
        it "dates the post today for #{description}" do
          preview(publish_at:)

          expect(page).to have_css(".post-meta time", exact_text: Blog::TimeZone.today.strftime("%b %-d, %Y"))
        end
      end

    describe "for the same markdown as a published post" do
      let(:body) { "## Heading\n\n`code` and *emphasis*\n\n```ruby\nputs :hi\n```\n\n> quote <b>tag</b>" }
      let(:article_body) do
        create(:post, :published, slug: "hello", body:)
        get "/writing/hello"
        page.find(".post .post-body").native.inner_html
      end

      it "renders the body as the public article does" do
        expected = article_body
        preview(body:)

        expect(page.find(".post-body").native.inner_html).to eq(expected)
      end
    end

    it "renders with no fields" do
      post "/admin/posts/preview", { _csrf_token: admin_csrf_token }

      expect(page).to have_css(".post-body", exact_text: "")
    end

    it "rejects a preview without a CSRF token" do
      preview(token: nil, title: "Hello")

      expect(last_response).to be_forbidden
    end
  end

  describe "signed out" do
    let(:session_token) do
      get "/admin/sign-in"
      last_request.env["rack.session"]["_csrf_token"]
    end

    it "redirects to sign-in" do
      preview(token: session_token, title: "Hello")

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "renders no preview" do
      preview(token: session_token, title: "Hello")

      expect(last_response.body).not_to include("preview-title")
    end
  end
end
