# frozen_string_literal: true

RSpec.describe "Admin tags on project tasks", type: :request do
  let(:podcast) { create(:project, name: "Podcast", key: "POD") }
  let(:task) { create(:task, title: "Record the intro", project_id: podcast.id, tags: %w[audio]) }

  before { sign_in_to_admin }

  it "links a project tag on the task page to the project's tag page" do
    get "/admin/tasks/#{task.id}"

    expect(page).to have_link("#audio", href: "/admin/projects/POD/tags/audio")
  end

  it "links a project tag on a board card to the project's tag page" do
    task
    get "/admin/projects/#{podcast.id}"

    expect(page.find(".kc", text: "Record the intro")).to have_link("#audio", href: "/admin/projects/POD/tags/audio")
  end

  it "names the project on the tags field of a project task and offers its tags", :aggregate_failures do
    get "/admin/tasks/#{task.id}/edit"

    expect(page).to have_field("POD tags", with: "audio")
    expect(page.find("#task-#{task.id}-tags + .tag-pick", visible: :all)["data-tag-field-src"])
      .to eq("/admin/tags/private/choices?project=#{podcast.id}")
  end

  it "offers a project's tags and no global ones as choices for it" do
    task
    create(:tag, :private, name: "home")
    get "/admin/tags/private/choices?project=#{podcast.id}"

    expect(JSON.parse(last_response.body).fetch("tags").map { it.fetch("name") }).to eq(%w[audio])
  end

  it "makes a project tag when the task editor saves a tag" do
    post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, task: { title: task.title, tags: "audio, mix" } }

    expect(Tags::Slice["repos.tag_queries"].all_in("project", project_id: podcast.id).map(&:name)).to eq(%w[audio mix])
  end
end
