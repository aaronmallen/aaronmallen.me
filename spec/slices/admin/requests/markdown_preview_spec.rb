# frozen_string_literal: true

RSpec.describe "Admin Markdown preview", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def preview(renderer, markdown, token: admin_csrf_token)
    post "/admin/markdown/preview/#{renderer}", { markdown: }, { "HTTP_X_CSRF_TOKEN" => token }
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers with the body alone and no layout", :aggregate_failures do
      preview("posts", "Hello *there*")

      expect(last_response).to be_ok
      expect(last_response.body).to start_with("<div class=\"post-body\">")
      expect(last_response.body).not_to include("<main")
    end

    it "renders through the post renderer" do
      preview("posts", "Hello *there*")

      expect(page).to have_css(".post-body em", exact_text: "there")
    end

    it "drops raw HTML through the post renderer" do
      preview("posts", "<details><summary>More</summary>hidden</details>")

      expect(page).to have_no_css(".post-body details")
    end

    it "keeps raw HTML the task renderer allows" do
      preview("tasks", "<details><summary>More</summary>hidden</details>")

      expect(page).to have_css(".post-body details summary", exact_text: "More")
    end

    it "strips a raw script through the task renderer", :aggregate_failures do
      preview("tasks", "before\n\n<script>alert(1)</script>\n\nafter")

      expect(last_response.body).not_to include("<script")
      expect(page).to have_css(".post-body p", exact_text: "after")
    end

    it "renders an empty body for no markdown" do
      post "/admin/markdown/preview/posts", { _csrf_token: admin_csrf_token }

      expect(page).to have_css(".post-body", exact_text: "")
    end

    %w[html tasksx Posts].each do |renderer|
      it "refuses the renderer #{renderer}" do
        preview(renderer, "Hello")

        expect(last_response).to be_not_found
      end
    end

    it "rejects a preview without a CSRF token" do
      preview("posts", "Hello", token: nil)

      expect(last_response).to be_forbidden
    end
  end

  describe "signed out" do
    let(:session_token) do
      get "/admin/sign-in"
      last_request.env["rack.session"]["_csrf_token"]
    end

    it "redirects to sign-in and renders nothing", :aggregate_failures do
      preview("posts", "Hello *there*", token: session_token)

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      expect(last_response.body).not_to include("<em>")
    end
  end
end
