# frozen_string_literal: true

RSpec.describe "Content types", type: :request do
  let(:html) { "text/html; charset=utf-8" }

  {
    "no Accept header" => {},
    "Accept: */*" => { "HTTP_ACCEPT" => "*/*" },
  }.each do |sent, env|
    describe "a page asked for with #{sent}" do
      it "answers HTML on the public site" do
        get "/writing", {}, env

        expect(last_response.content_type).to eq(html)
      end

      it "answers HTML on the admin" do
        sign_in_to_admin
        get "/admin/posts", {}, env

        expect(last_response.content_type).to eq(html)
      end

      it "answers HTML on the admin sign in page" do
        get "/admin/sign-in", {}, env

        expect(last_response.content_type).to eq(html)
      end

      it "answers the post preview as HTML" do
        sign_in_to_admin
        post "/admin/posts/preview", { post: { title: "Hello" } }, env.merge("HTTP_X_CSRF_TOKEN" => admin_csrf_token)

        expect(last_response.content_type).to eq(html)
      end
    end
  end

  it "turns away a page asked for in a format it does not serve" do
    get "/writing", {}, "HTTP_ACCEPT" => "application/json"

    expect(last_response.status).to eq(406)
  end
end
