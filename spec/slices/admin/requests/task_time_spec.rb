# frozen_string_literal: true

RSpec.describe "Admin task time", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:started) { Time.at(((Time.now.to_i - 86_400) / 60) * 60) }
  let(:task) { create(:task, worked_seconds: 3600) }

  def closed(from: started, to: started + 1800, on: task)
    create(:work_session, task_id: on.id, started_at: from, ended_at: to)
  end

  def complete(**worked) = send_to("/admin/tasks/#{task.id}/complete", worked:)

  def edit(session, on: task, **times)
    send_to("/admin/tasks/#{on.id}/sessions/#{session[:id]}", session: times.transform_values { local(it) })
  end

  def local(time) = time.is_a?(Time) ? Blog::TimeZone.input_value(time) : time

  def read = get("/admin/tasks/#{task.id}", filter: "next")

  def running_task(since: started)
    found = create(:task, :in_progress, :in_sprint, worked_seconds: 600)
    create(:work_session, task_id: found.id, started_at: since)
    found
  end

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, filter: "next", **params })

  def sessions(on = task) = Tasks::Slice["relations.work_sessions"].for_task(on.id).order(:started_at).to_a

  def set_total(**total) = send_to("/admin/tasks/#{task.id}/total", total:)

  def t(key, **) = i18n.t(key, **)

  def total(on = task) = repo.by_id(on.id).worked_seconds

  describe "signed out" do
    it "edits no session" do
      session = closed
      post "/admin/tasks/#{task.id}/sessions/#{session.id}", session: { started_at: local(started - 600) }

      expect(sessions.first[:started_at]).to eq(started)
    end

    it "deletes no session" do
      closed
      post "/admin/tasks/#{task.id}/sessions/#{sessions.first[:id]}/delete"

      expect(sessions.size).to eq(1)
    end

    it "sets no total" do
      post "/admin/tasks/#{task.id}/total", total: { hours: "9" }

      expect(total).to eq(3600)
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "editing a session" do
      it "shifts the total by a later end", :aggregate_failures do
        edit(closed, started_at: started, ended_at: started + 2700)

        expect(sessions.first[:ended_at]).to eq(started + 2700)
        expect(total).to eq(4500)
      end

      it "shifts the total by a later start" do
        edit(closed, started_at: started + 600, ended_at: started + 1800)

        expect(total).to eq(3000)
      end

      it "keeps the seconds of a time left in the same minute", :aggregate_failures do
        session = closed(from: started + 15, to: started + 1845)
        edit(session, started_at: started, ended_at: started + 2700)

        expect(sessions.first[:started_at]).to eq(started + 15)
        expect(total).to eq(4455)
      end

      it "answers with the toast and the list" do
        edit(closed, started_at: started, ended_at: started + 2700)

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
      end

      it "moves only the start of a running session and leaves the total", :aggregate_failures do
        found = running_task
        edit(sessions(found).first, on: found, started_at: started - 600, ended_at: started)

        expect(sessions(found).map { [it[:started_at], it[:ended_at]] }).to eq([[started - 600, nil]])
        expect(total(found)).to eq(600)
      end

      it "refuses a running session that starts later than now" do
        found = running_task
        edit(sessions(found).first, on: found, started_at: Time.now + 7200)

        expect([last_response.status, sessions(found).first[:started_at]]).to eq([422, started])
      end

      it "refuses an end later than now and changes nothing", :aggregate_failures do
        edit(closed, started_at: started, ended_at: Time.now + 7200)

        expect(last_response.status).to eq(422)
        error = page.find("#task-session-#{sessions.first[:id]}-ended-at-error")
        expect(error).to have_text(t("ui.components.tasks.field_error.ended_at.future"))
        expect([sessions.first[:ended_at], total]).to eq([started + 1800, 3600])
      end

      it "refuses a finished session that starts later than now", :aggregate_failures do
        edit(closed, started_at: Time.now + 7200, ended_at: Time.now + 9000)

        expect(last_response.status).to eq(422)
        expect(page.find("#task-session-#{sessions.first[:id]}-started-at-error"))
          .to have_text(t("ui.components.tasks.field_error.started_at.future"))
      end

      it "refuses an end before the start and changes nothing", :aggregate_failures do
        edit(closed, started_at: started, ended_at: started - 60)

        expect(last_response.status).to eq(422)
        error = page.find("#task-session-#{sessions.first[:id]}-ended-at-error")
        expect(error).to have_text(t("ui.components.tasks.field_error.ended_at.order"))
        expect([sessions.first[:ended_at], total]).to eq([started + 1800, 3600])
      end

      it "keeps what was typed when it refuses" do
        session = closed
        edit(session, started_at: started, ended_at: "nonsense")

        expect(page.find("#task-session-#{session.id}-started-at")["value"]).to eq(local(started))
      end

      it "refuses a blank start" do
        edit(closed, started_at: "", ended_at: started)

        expect(page).to have_text(t("ui.components.tasks.field_error.started_at.blank"))
      end

      it "answers 404 for another task's session" do
        edit(closed(on: create(:task)), started_at: started, ended_at: started + 60)

        expect(last_response.status).to eq(404)
      end
    end

    describe "deleting a session" do
      it "drops the total by its length" do
        session = closed
        send_to("/admin/tasks/#{task.id}/sessions/#{session.id}/delete")

        expect([sessions, total]).to eq([[], 1800])
      end

      it "takes it off the timeline" do
        session = closed
        send_to("/admin/tasks/#{task.id}/sessions/#{session.id}/delete")
        read

        expect(page).to have_no_css(".timeline-event[data-task-event='session']")
      end

      it "leaves no other mark on the timeline" do
        send_to("/admin/tasks/#{task.id}/sessions/#{closed.id}/delete")
        read

        expect(page).to have_css(".timeline-card .hint", text: t("ui.components.tasks.timeline.empty"))
      end

      it "keeps the total at zero or more" do
        Tasks::Slice["repos.task_mutations"].update(task.id, worked_seconds: 60)
        send_to("/admin/tasks/#{task.id}/sessions/#{closed.id}/delete")

        expect(total).to eq(0)
      end

      def refuse_running(since: Time.at(((Time.now.to_i - 600) / 60) * 60))
        found = running_task(since:)
        session = sessions(found).first
        send_to("/admin/tasks/#{found.id}/sessions/#{session[:id]}/delete")
        [found, session, since]
      end

      it "refuses the running session with the reason beside it", :aggregate_failures do
        _, session = refuse_running

        expect(last_response.status).to eq(422)
        expect(page.find("#task-session-#{session[:id]}-ended-at-error"))
          .to have_text(t("ui.components.tasks.field_error.ended_at.running"))
      end

      it "keeps the saved start in the form it reopens" do
        _, session, since = refuse_running

        expect(page.find("#task-session-#{session[:id]}-started-at")["value"]).to eq(local(since))
      end

      it "keeps the running session open and the task in progress", :aggregate_failures do
        found, session = refuse_running

        expect(sessions(found).map { it[:id] }).to include(session[:id])
        expect(sessions(found).count { it[:ended_at].nil? }).to eq(1)
        expect(repo.by_id(found.id).status).to eq("in_progress")
      end

      it "has no delete form on the running session while a closed one keeps it", :aggregate_failures do
        found = running_task(since: started + 3600)
        finished = closed(on: found)
        get("/admin/tasks/#{found.id}", filter: "next")

        expect(page).to have_no_css("form[action$='/sessions/#{sessions(found).last[:id]}/delete']", visible: :all)
        expect(page).to have_css("form[action$='/sessions/#{finished.id}/delete']", visible: :all)
      end

      it "answers 404 for another task's session" do
        send_to("/admin/tasks/#{task.id}/sessions/#{closed(on: create(:task)).id}/delete")

        expect(last_response.status).to eq(404)
      end
    end

    describe "setting the total" do
      it "replaces the total" do
        set_total(hours: "2", minutes: "15")

        expect(total).to eq(8100)
      end

      it "adds a later session to the number set" do
        set_total(hours: "", minutes: "20")
        found = repo.by_id(task.id)
        Tasks::Slice["operations.start_task"].call(found.id, at: started)
        Tasks::Slice["operations.reopen_task"].call(found.id, at: started + 600)

        expect(total).to eq(1800)
      end

      it "counts a running session's time so far in the number set", :aggregate_failures do
        found = running_task
        send_to("/admin/tasks/#{found.id}/total", total: { hours: "1" })

        expect(total(found)).to eq(3600)
        expect(sessions(found).map { it[:ended_at].nil? }).to eq([false, true])
      end

      it "refuses a blank total", :aggregate_failures do
        set_total(hours: "", minutes: "")

        expect(last_response.status).to eq(422)
        expect(page).to have_text(t("ui.components.tasks.field_error.hours.blank"))
        expect(total).to eq(3600)
      end

      it "refuses minutes past 59" do
        set_total(hours: "1", minutes: "75")

        message = t("ui.components.tasks.field_error.minutes.format")

        expect(page).to have_css("details.task-total-edit[open]", text: message)
      end

      it "shows the form on the timeline filled with the total", :aggregate_failures do
        read

        expect(page.find(".task-total-edit input[name='total[hours]']", visible: :all)["value"]).to eq("1")
        expect(page.find(".task-total-edit input[name='total[minutes]']", visible: :all)["value"]).to eq("0")
      end

      it "caps the fields at the limits the server holds", :aggregate_failures do
        read

        expect(page.find(".task-total-edit input[name='total[hours]']", visible: :all)["max"]).to eq("9999")
        expect(page.find(".task-total-edit input[name='total[minutes]']", visible: :all)["max"]).to eq("59")
      end
    end

    describe "completing a task by hand" do
      let(:task) { running_task(since: Time.at(Time.now.to_i - 1800)) }

      def field(name) = page.find("form[action$='/complete'] input[name='worked[#{name}]']", visible: :all)

      it "asks how long it took, filled with the tracked time", :aggregate_failures do
        read

        legend = page.find("form[action$='/complete'] legend", visible: :all)
        expect(legend.text(:all)).to eq(t("ui.components.tasks.complete_form.ask"))
        expect([field(:hours)["value"], field(:minutes)["value"]]).to eq(%w[0 40])
      end

      it "keeps the tracked total when the answer is left as it was", :aggregate_failures do
        complete(hours: "0", minutes: "40", tracked: "2400")

        expect(repo.by_id(task.id).status).to eq("done")
        expect(total).to be_within(5).of(2400)
      end

      it "keeps the tracked total when the answer is blank" do
        complete(hours: "", minutes: "")

        expect(total).to be_within(5).of(2400)
      end

      it "replaces the total with a new number" do
        complete(hours: "3", minutes: "5", tracked: "2400")

        expect(total).to eq(11_100)
      end

      it "still completes when no answer is sent" do
        send_to("/admin/tasks/#{task.id}/complete")

        expect([repo.by_id(task.id).status, total]).to match(["done", be_within(5).of(2400)])
      end

      it "refuses an answer out of range and leaves the task open", :aggregate_failures do
        complete(hours: "-1", minutes: "0", tracked: "2400")

        expect(repo.by_id(task.id).status).to eq("in_progress")
        expect(last_response).to be_redirect
      end
    end
  end
end
