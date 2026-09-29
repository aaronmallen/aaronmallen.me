# frozen_string_literal: true

RSpec.describe "Admin task comments", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:comments) { Tasks::Slice["relations.task_comments"] }
  let(:task) { create(:task, title: "Ship the comments") }

  def add(body, id: task.id, **returns)
    send_to("/admin/tasks/#{id}/comments", filter: "next", **returns, comment: { body: })
  end

  def bodies = comments.order(:id).to_a.map { it[:body] }

  def comment_on_page(comment) = page.find("[data-task-comment='#{comment.id}']")

  def delete(comment) = send_to("/admin/tasks/#{task.id}/comments/#{comment.id}/delete", filter: "next")

  def edit(comment, body)
    send_to("/admin/tasks/#{task.id}/comments/#{comment.id}", filter: "next", comment: { body: })
  end

  def read = get("/admin/tasks/#{task.id}", filter: "next")

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def t(key, **) = i18n.t(key, **)

  describe "signed out" do
    it "adds nothing" do
      post "/admin/tasks/#{task.id}/comments", comment: { body: "Hello" }

      expect(bodies).to be_empty
    end

    it "edits nothing" do
      comment = create(:task_comment, task_id: task.id, body: "Before")
      post "/admin/tasks/#{task.id}/comments/#{comment.id}", comment: { body: "After" }

      expect(bodies).to eq(["Before"])
    end

    it "deletes nothing" do
      comment = create(:task_comment, task_id: task.id)
      post "/admin/tasks/#{task.id}/comments/#{comment.id}/delete"

      expect(comments.to_a.size).to eq(1)
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list on the task page" do
      it "says when there are none" do
        read

        expect(page).to have_css(".task-comments .hint", text: t("ui.components.tasks.comments.empty"))
      end

      it "lists them oldest first" do
        create(:task_comment, task_id: task.id, body: "Second", created_at: Time.now - 60)
        create(:task_comment, task_id: task.id, body: "Third", created_at: Time.now)
        create(:task_comment, task_id: task.id, body: "First", created_at: Time.now - 120)
        read

        expect(page.all(".task-comment-body").map(&:text)).to eq(%w[First Second Third])
      end

      it "leaves out another task's comments" do
        create(:task_comment, body: "Elsewhere")
        read

        expect(page).to have_no_css(".task-comment")
      end

      it "renders the body as markdown" do
        create(:task_comment, task_id: task.id, body: "say **why**")
        read

        expect(page).to have_css(".task-comment-body strong", exact_text: "why")
      end

      it "strips script from the body", :aggregate_failures do
        create(:task_comment, task_id: task.id, body: "<script>alert(1)</script><a href=\"javascript:alert(1)\">x</a>")
        read

        expect(page).to have_no_css(".task-comment-body script")
        expect(page.find(".task-comment-body a")["href"]).to be_nil
      end

      it "names the owner and the time on a local comment", :aggregate_failures do
        comment = create(:task_comment, task_id: task.id)
        read

        expect(comment_on_page(comment)).to have_css(".task-comment-author", exact_text: Blog::Owner.full_name)
        expect(comment_on_page(comment).find("time")["datetime"]).to eq(comment.created_at.iso8601)
      end

      it "offers edit on a local comment" do
        comment = create(:task_comment, task_id: task.id)
        read

        expect(comment_on_page(comment)).to have_css(
          "form[action='/admin/tasks/#{task.id}/comments/#{comment.id}'] textarea[name='comment[body]']", visible: :all,
        )
      end

      it "offers delete on a local comment" do
        comment = create(:task_comment, task_id: task.id)
        read

        expect(comment_on_page(comment))
          .to have_css("form[action='/admin/tasks/#{task.id}/comments/#{comment.id}/delete'][data-confirm]")
      end
    end

    describe "a synced comment" do
      let!(:comment) { create(:task_comment, :synced, task_id: task.id, author: "octocat") }

      before { read }

      it "shows its author" do
        expect(comment_on_page(comment)).to have_css(".task-comment-author", exact_text: "octocat")
      end

      it "shows its time" do
        expect(comment_on_page(comment).find("time")["datetime"]).to eq(comment.created_at.iso8601)
      end

      it "links back to the provider" do
        expect(comment_on_page(comment).find("a.task-source")["href"]).to eq(comment.url)
      end

      it "offers no edit or delete", :aggregate_failures do
        expect(comment_on_page(comment)).to have_no_css("form")
        expect(comment_on_page(comment)).to have_no_css("details")
      end

      it "refuses an edit" do
        edit(comment, "Changed here")

        expect([last_response.status, comments.by_pk(comment.id).one[:body]]).to eq([404, comment.body])
      end

      it "refuses a delete" do
        delete(comment)

        expect([last_response.status, comments.to_a.size]).to eq([404, 1])
      end
    end

    describe "adding a comment" do
      it "saves it, trimmed" do
        add("  Looked into it  ")

        expect(comments.to_a.map { it.to_h.values_at(:task_id, :body, :remote_id) })
          .to eq([[task.id, "Looked into it", nil]])
      end

      it "comes back to the list that was open" do
        add("Hello")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
      end

      it "comes back to Today when it was added there" do
        add("Hello", filter: "today", origin: "today")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
      end

      it "says so" do
        add("Hello")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("tasks_page.toasts.comment_added"))
      end

      it "shows on the task page afterward" do
        add("Hello there")
        read

        expect(page).to have_css(".task-comment-body", exact_text: "Hello there")
      end

      it "answers 404 for a task that isn't there" do
        add("Hello", id: 404_404)

        expect(last_response.status).to eq(404)
      end

      it "keeps nothing when the body is missing" do
        send_to("/admin/tasks/#{task.id}/comments", filter: "next")

        expect([last_response.status, bodies]).to eq([422, []])
      end
    end

    describe "adding an empty comment" do
      before { add("   ") }

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "says why beside the field", :aggregate_failures do
        expect(page.find("#task-#{task.id}-comment-body-error").text)
          .to eq(t("ui.components.tasks.field_error.body.blank"))
        expect(page.find("#task-#{task.id}-comment-body")["aria-describedby"])
          .to eq("task-#{task.id}-comment-body-error")
      end

      it "shows the task page" do
        expect(page).to have_css("[data-task-read='#{task.id}']")
      end

      it "keeps nothing" do
        expect(bodies).to be_empty
      end
    end

    describe "editing a comment" do
      let!(:comment) { create(:task_comment, task_id: task.id, body: "Before") }

      it "saves the new body" do
        edit(comment, "After")

        expect(bodies).to eq(["After"])
      end

      it "says so" do
        edit(comment, "After")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("tasks_page.toasts.comment_saved"))
      end

      it "answers 404 for a comment on another task" do
        other = create(:task_comment, body: "Elsewhere")
        edit(other, "Changed")

        expect([last_response.status, comments.by_pk(other.id).one[:body]]).to eq([404, "Elsewhere"])
      end
    end

    describe "editing a comment to nothing" do
      let!(:comment) { create(:task_comment, task_id: task.id, body: "Before") }

      before { edit(comment, " ") }

      it "answers 422 with the error on that comment's form", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page.find("#task-#{task.id}-comment-#{comment.id}-body-error").text)
          .to eq(t("ui.components.tasks.field_error.body.blank"))
      end

      it "opens that comment's form" do
        expect(comment_on_page(comment)).to have_css("details.task-comment-edit[open]")
      end

      it "leaves the new comment field clean" do
        expect(page).to have_no_css("#task-#{task.id}-comment-body-error")
      end

      it "keeps the old body" do
        expect(bodies).to eq(["Before"])
      end
    end

    describe "deleting a comment" do
      let!(:comment) { create(:task_comment, task_id: task.id) }

      it "removes it" do
        delete(comment)

        expect(bodies).to be_empty
      end

      it "says so" do
        delete(comment)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("tasks_page.toasts.comment_deleted"))
      end

      it "answers 404 for a comment that isn't there" do
        delete(comment)
        delete(comment)

        expect(last_response.status).to eq(404)
      end
    end

    it "removes a task's comments with the task" do
      create(:task_comment, task_id: task.id)
      send_to("/admin/tasks/#{task.id}/delete", filter: "next")

      expect(comments.to_a).to be_empty
    end
  end
end
