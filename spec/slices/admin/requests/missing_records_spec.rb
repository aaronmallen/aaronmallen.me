# frozen_string_literal: true

RSpec.describe "Admin records that are gone", type: :request do
  missing = 999_999

  {
    "/journal/#{missing}" => { entry: { body: "after" } },
    "/journal/#{missing}/delete" => {},
    "/messages/#{missing}/mark/read" => {},
    "/posts/#{missing}" => { post: { title: "Hello", body: "hi" } },
    "/posts/#{missing}/delete" => {},
    "/projects/#{missing}" => { project: { name: "Blog" } },
    "/projects/#{missing}/archive" => {},
    "/projects/work/#{missing}/delete" => {},
    "/tags/#{missing}" => { tag: { name: "hanami" } },
    "/tags/#{missing}/delete" => {},
    "/tasks/#{missing}" => { task: { title: "mow the lawn" } },
    "/tasks/#{missing}/complete" => {},
    "/tasks/#{missing}/delete" => {},
    "/tasks/#{missing}/links" => { link: { key: "T-1", kind: "blocks" } },
    "/tasks/#{missing}/move/today" => {},
    "/tasks/#{missing}/reopen" => {},
    "/tasks/#{missing}/reorder/up" => {},
    "/tasks/#{missing}/schedule" => {},
    "/tasks/#{missing}/start" => {},
    "/tasks/#{missing}/stop" => {},
    "/tasks/sprints/#{missing}/delete" => {},
    "/webmentions/#{missing}/approve" => {},
    "/webmentions/#{missing}/spam" => {},
  }.each do |path, params|
    it "answers 404 to a POST to /admin#{path}" do
      sign_in_to_admin
      post "/admin#{path}", _csrf_token: admin_csrf_token, **params

      expect(last_response.status).to eq(404)
    end
  end
end
