# frozen_string_literal: true

RSpec.describe "Admin post syndication preview", type: :request do
  def preview(token: admin_csrf_token, **fields)
    post "/admin/posts/preview/syndication", { post: fields }, { "HTTP_X_CSRF_TOKEN" => token }
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers with the cross-post text and no markup", :aggregate_failures do
      preview(title: "Hello", slug: "hello")

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with("text/plain")
      expect(last_response.body).to eq("Hello\n\nhttps://aaronmallen.me/writing/hello")
    end

    it "takes the slug the save would derive from the title" do
      preview(title: "Hello There", slug: "")

      expect(last_response.body).to eq("Hello There\n\nhttps://aaronmallen.me/writing/hello-there")
    end

    it "answers with nothing for a blank title" do
      preview(title: "  ", slug: "hello")

      expect(last_response.body).to eq("")
    end

    it "answers with nothing for no fields at all" do
      post "/admin/posts/preview/syndication", { _csrf_token: admin_csrf_token }

      expect(last_response.body).to eq("")
    end

    it "saves no post" do
      expect { preview(title: "Hello", slug: "hello") }
        .not_to(change { Posts::Slice["repos.post_queries"].all.count })
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
  end
end
