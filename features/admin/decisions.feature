Feature: Admin decisions
  The owner opens decisions in the admin, weighs their options, then resolves, drops or reopens them. Each open
  decision keeps a task on the next list.

  Background:
    Given I am signed in to the admin

  Scenario: The list shows the open decisions, newest first, with their keys, counts and links
    Given an open decision "Older open" opened 1 hour ago
    And an open decision "Newer open" opened 0 hours ago
    And a dropped decision "Gone" opened 0 hours ago
    When I visit "/admin/decisions"
    Then the decisions admin lists ".decision-row .decision-row-title" as "Newer open, Older open"
    And the decisions admin lists the data-record-key of ".decision-row button.record-key" as "#2, #1"
    And the decisions admin lists ".decision-tabs a" as "open2, resolved0, dropped1"
    And the decisions admin shows ".page-head-sub" reading "2 decisions wait on a choice. 0 resolved, 1 dropped."
    And the decisions admin's ".decision-row-title >> text=Newer open" has the href "/admin/decisions/2"
    And the decisions admin shows ".screen-tab[aria-current='page']" reading "decisions"

  Scenario: The dropped filter lists the dropped decisions and marks its tab
    Given an open decision "Older open" opened 1 hour ago
    And a dropped decision "Gone" opened 0 hours ago
    When I visit "/admin/decisions?status=dropped"
    Then the decisions admin lists ".decision-row .decision-row-title" as "Gone"
    And the decisions admin shows ".decision-tabs a[aria-current='page'][href='/admin/decisions?status=dropped']"

  Scenario: The list says when no decision has the status
    Given an open decision "Older open" opened 1 hour ago
    When I visit "/admin/decisions?status=resolved"
    Then the decisions admin shows ".empty" reading "Nothing resolved yet."

  Scenario: The list shows the open decisions for a status it does not know
    Given an open decision "Older open" opened 1 hour ago
    And an open decision "Newer open" opened 0 hours ago
    And a dropped decision "Gone" opened 0 hours ago
    When I visit "/admin/decisions?status=junk"
    Then the decisions admin lists ".decision-row .decision-row-title" as "Newer open, Older open"

  Scenario: The lede says nothing waits when every decision is closed
    Given a dropped decision "Gone" opened 0 hours ago
    When I visit "/admin/decisions"
    Then the decisions admin shows ".page-head-sub" reading "Nothing waits on a choice."

  Scenario: A row counts its options and puts when it opened in a time tag
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    And the database runs:
      """
      insert into decisions (title, problem, created_at) values ('Dated', 'It came up', '2026-09-07 17:30Z')
      """
    When I visit "/admin/decisions"
    Then the decisions admin shows ".decision-row:has-text('Pick a queue') .decision-meta" reading "1 option"
    And the decisions admin's ".decision-row:has-text('Dated') .decision-meta time" has the datetime "2026-09-07T12:30:00-05:00"

  Scenario: A resolved row names its choice and shows its comments, tags and status
    Given a decision "Resolved one" with the problem "It came up"
    And the decision "Resolved one" has the option "Sidekiq"
    And the decision "Resolved one" carries the tag "queues"
    And the decision "Resolved one" has the comment "Looks fine"
    And the database runs:
      """
      update decisions set status = 'resolved', resolved_option_id = 1
      """
    When I visit "/admin/decisions?status=resolved"
    Then the decisions admin shows ".decision-row:has-text('Resolved one') .decision-chosen" reading "Sidekiq"
    And the decisions admin shows ".decision-row:has-text('Resolved one') .decision-meta" reading "1 comment"
    And the decisions admin shows ".decision-row:has-text('Resolved one') .tag" reading "#queues"
    And the decisions admin shows ".decision-row:has-text('Resolved one') .pill" reading "resolved"

  Scenario: The list answers 404 past the last page
    Then visiting "/admin/decisions?page=2" answers 404

  Scenario: The palette offers decisions
    When I visit "/admin"
    Then the decisions admin shows "#command-palette-decisions[data-palette-href='/admin/decisions'] i.fa-scale-balanced"

  Scenario: The new decision form asks for the problem and links back to the list
    When I visit "/admin/decisions/new"
    Then the decisions admin shows "form[action='/admin/decisions'] textarea[name='decision[problem]']"
    And the decisions admin shows "a.bt[href='/admin/decisions']" reading "All decisions"
    And the decisions admin shows "a.bt[href='/admin/decisions'] > i.fa-solid.fa-arrow-left[aria-hidden='true']:first-child"
    And the decisions admin shows no "a.bt[href='/admin/decisions'][type], a.bt[href='/admin/decisions'][disabled]"

  Scenario: Opening a decision saves it with its tags, adds its task and goes to its page
    Given the database runs:
      """
      insert into tasks (title, list, position) values ('Earlier', 'next', 5)
      """
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a host     |
      | decision[problem] | The Pi is slow  |
      | decision[tags]    | hosting         |
    Then the decisions admin lands on "/admin/decisions/1"
    And the decisions admin shows "[data-toast]" reading "Decision opened"
    And the database answers "Pick a host, The Pi is slow, open, hosting" for:
      """
      select d.title, d.problem, d.status, t.name from decisions d
      join decision_tags dt on dt.decision_id = d.id join tags t on t.id = dt.tag_id
      """
    And the database answers "Earlier | Resolve decision #1: Pick a host" for:
      """
      select string_agg(title, ' | ' order by position) from tasks where list = 'next'
      """
    And the database answers "task, 2, decision, 1, sourced_from" for:
      """
      select left_kind, left_id, right_kind, right_id, relation from record_links
      """

  Scenario: Opening a decision with a blank problem says why beside the field
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a host |
      | decision[problem] | " "         |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-problem-error" reading "Say what needs a choice."
    And the decisions admin's "[name='decision[title]']" holds "Pick a host"
    And the decisions admin shows "#decision-problem[aria-invalid='true'][aria-describedby='decision-problem-error']"

  Scenario: The decision page shows the decision, its options, its tags and its forms
    Given a decision "Pick a queue" with the problem "Jobs **pile** up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs *today*"
    And the decision "Pick a queue" carries the tag "queues"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Elsewhere"
    When I visit "/admin/decisions/1"
    Then the decisions admin shows "h1" reading "Pick a queue"
    And the decisions admin shows ".pill" reading "open"
    And the decisions admin shows ".markdown-body strong" reading "pile"
    And the decisions admin shows ".read-meta button.record-key[data-record-key='#1']" reading "#1"
    And the decisions admin shows "[data-decision-option='1'] .markdown-body em" reading "today"
    And the decisions admin shows "details.decision-add:not([open]) form[action='/admin/decisions/1/options'] input[name='option[title]']"
    And the decisions admin's "form[action='/admin/decisions/1/options/1'] [name='option[title]']" holds "Sidekiq"
    And the decisions admin shows no "form[action='/admin/decisions/1/options/1'] [name='option[note]']"
    And the decisions admin lists "select[name='decision[option_id]'] option" as "Pick an option, Sidekiq"
    And the decisions admin shows "form[action='/admin/decisions/1/drop']"
    And the decisions admin shows no "form[action='/admin/decisions/1/reopen']"
    And the decisions admin shows ".read-meta .tag" reading "#queues"
    And the decisions admin's ".read-meta a:has-text('#queues')" has the href "/admin/tags/queues"

  Scenario: A decision that is not there answers 404
    Then visiting "/admin/decisions/999999" answers 404

  Scenario: A decision with no options says to add one before it resolves
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I visit "/admin/decisions/1"
    Then the decisions admin shows no "form[action='/admin/decisions/1/resolve']"
    And the decisions admin shows ".hint" reading "Add an option before you resolve it."
    And the decisions admin shows ".hint" reading "No options yet."

  Scenario: Adding an option saves it and comes back to the decision
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | Good Job      |
      | option[body]  | Uses Postgres |
    Then the decisions admin lands on "/admin/decisions/1"
    And the database answers "Good Job, Uses Postgres" for:
      """
      select title, body from decision_options
      """

  Scenario: Adding an option with a blank title keeps what was typed
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | " "           |
      | option[body]  | Uses Postgres |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-option-new-title-error"
    And the decisions admin's "form[action='/admin/decisions/1/options'] [name='option[body]']" holds "Uses Postgres"

  Scenario: Adding an option to a closed decision is turned away
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | Late |
      | option[body]  | ""   |
    Then the decisions admin shows "[data-toast]" reading "That decision is closed already"

  Scenario: Editing an option on an open decision saves it without a note
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I post to the decisions admin at "/admin/decisions/1/options/1" with:
      | option[title] | Sidekiq 8  |
      | option[body]  | Runs today |
    Then the database answers "Sidekiq 8" for:
      """
      select title from decision_options
      """

  Scenario: Editing another decision's option answers 404
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Elsewhere"
    When I post to the decisions admin at "/admin/decisions/1/options/1" with:
      | option[title] | Mine |
      | option[body]  | ""   |
    Then the decisions admin answers 404

  Scenario: A closed decision's option form asks for a note
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    And I visit "/admin/decisions/1"
    Then the decisions admin shows "form[action='/admin/decisions/1/options/1'] [name='option[note]'][placeholder='Added the cost of running it.']"
    And the decisions admin shows "form[action='/admin/decisions/1/options/1'] .hint" reading "A closed decision needs one when its problem or an option changes. It goes on the timeline."

  Scenario: Saving a closed decision's option without a note says why and keeps what was typed
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    And I post to the decisions admin at "/admin/decisions/1/options/1" with:
      | option[title] | Sidekiq 8  |
      | option[body]  | Runs today |
    Then the decisions admin answers 422
    And the database answers "Sidekiq" for:
      """
      select title from decision_options
      """
    And the decisions admin shows "#decision-option-1-note-error" reading "Say what changed and why. A closed decision needs a note."
    And the decisions admin shows "details[open] input[name='option[title]'][value='Sidekiq 8']"

  Scenario: Saving a closed decision's option with a note puts the note on the timeline
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    And I post to the decisions admin at "/admin/decisions/1/options/1" with:
      | option[title] | Sidekiq 8  |
      | option[body]  | Runs today |
      | option[note]  | Renamed it |
    Then the database answers "Sidekiq 8" for:
      """
      select title from decision_options
      """
    And the database answers "option_edited, Renamed it" for:
      """
      select kind, note from decision_events order by id desc limit 1
      """
    When I visit "/admin/decisions/1"
    Then the decisions admin shows "[data-decision-event='option_edited'] .markdown-body" reading "Renamed it"

  Scenario: The edit form has no note while the decision is open
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I visit "/admin/decisions/1/edit"
    Then the decisions admin's "[name='decision[title]']" holds "Pick a queue"
    And the decisions admin shows no "[name='decision[note]']"

  Scenario: Saving the decision comes back to it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue      |
      | decision[problem] | Jobs pile up fast |
    Then the decisions admin lands on "/admin/decisions/1"
    And the database answers "Jobs pile up fast" for:
      """
      select problem from decisions
      """

  Scenario: Saving a decision that is not there answers 404
    When I post to the decisions admin at "/admin/decisions/999999" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    Then the decisions admin answers 404

  Scenario: Editing the tags adds and removes them and fills the field
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
      | decision[tags]    | queues, ruby |
    And I visit "/admin/decisions/1/edit"
    Then the decisions admin's "[name='decision[tags]']" holds "queues, ruby"
    When I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
      | decision[tags]    | ruby         |
    Then the database answers "ruby, private" for:
      """
      select t.name, t.scope from decision_tags dt join tags t on t.id = dt.tag_id
      """

  Scenario: A tag that is not a slug is refused beside the field
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
      | decision[tags]    | two words!   |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-tags-error" reading "A tag is lowercase words joined by hyphens."
    And the decisions admin's "[name='decision[tags]']" holds "two words!"

  Scenario: A closed decision's edit form asks for a note
    Given a dropped decision "Pick a queue" opened 0 hours ago
    When I visit "/admin/decisions/1/edit"
    Then the decisions admin shows "[name='decision[note]'][placeholder='Added the cost of running it.']"
    And the decisions admin shows ".hint" reading "A closed decision needs one when its problem or an option changes. It goes on the timeline."

  Scenario: A closed decision's new problem without a note is refused
    Given a decision "Pick a queue" with the problem "Jobs **pile** up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue      |
      | decision[problem] | Jobs pile up fast |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-note-error" reading "Say what changed and why. A closed decision needs a note."
    And the database answers "Jobs **pile** up" for:
      """
      select problem from decisions
      """

  Scenario: A note over the limit names the limit
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue      |
      | decision[problem] | Jobs pile up fast |
      | decision[note]    | 501 × a           |
    Then the decisions admin shows "#decision-note-error" reading "Keep the note to 500 characters or fewer."

  Scenario: A closed decision takes a new title without a note
    Given a decision "Pick a queue" with the problem "Jobs **pile** up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a job queue |
      | decision[problem] | Jobs **pile** up |
    Then the database answers "Pick a job queue" for:
      """
      select title from decisions
      """

  Scenario: A closed decision's new problem with a note saves it and puts the note on the timeline
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue      |
      | decision[problem] | Jobs pile up fast |
      | decision[note]    | Measured it       |
    Then the database answers "Jobs pile up fast" for:
      """
      select problem from decisions
      """
    And the database answers "edited, Measured it" for:
      """
      select kind, note from decision_events order by id desc limit 1
      """
    When I visit "/admin/decisions/1"
    Then the decisions admin shows "[data-decision-event='edited'] .markdown-body" reading "Measured it"

  Scenario: Resolving saves the choice and the reason and marks the chosen option
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    Then the database answers "resolved, 1" for:
      """
      select status, resolved_option_id from decisions
      """
    And the database answers "resolved, 1, It runs" for:
      """
      select kind, option_id, reason from decision_events order by id desc limit 1
      """
    And the decisions admin shows "[data-decision-option='1'] .pill" reading "chosen"
    And the decisions admin shows ".page-head-sub" reading "Chose Sidekiq."

  Scenario: Resolving with another decision's option is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Elsewhere"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 2       |
      | decision[reason]    | It runs |
    Then the database answers "open" for:
      """
      select status from decisions where id = 1
      """
    And the decisions admin shows "#decision-resolve-option-id-error" reading "Pick one of this decision's options."

  Scenario: Resolving with no option is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | ""      |
      | decision[reason]    | It runs |
    Then the decisions admin answers 422
    And the database answers "open" for:
      """
      select status from decisions
      """

  Scenario: Resolving with a blank reason keeps the choice and says why
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1   |
      | decision[reason]    | " " |
    Then the decisions admin shows "#decision-resolve-reason-error" reading "Say why."
    And the decisions admin shows "select[name='decision[option_id]'] option[selected]" reading "Sidekiq"
    And the decisions admin's "#decision-resolve-reason" has the aria-describedby "decision-resolve-reason-error"
    And the database answers "open" for:
      """
      select status from decisions
      """

  Scenario: Dropping closes the decision with the reason
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    Then the database answers "dropped" for:
      """
      select status from decisions
      """
    And the database answers "dropped, No need" for:
      """
      select kind, reason from decision_events order by id desc limit 1
      """

  Scenario: Dropping with a blank reason is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | "" |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-drop-reason-error"
    And the database answers "open" for:
      """
      select status from decisions
      """

  Scenario: Dropping a closed decision is turned away
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | Again |
    Then the decisions admin shows "[data-toast]" reading "That decision is closed already"

  Scenario: A dropped decision offers to reopen it and not to resolve or drop it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I visit "/admin/decisions/1"
    Then the decisions admin shows "form[action='/admin/decisions/1/reopen']"
    And the decisions admin shows no "form[action$='/drop'], form[action$='/resolve']"

  Scenario: Reopening opens the decision again with the reason
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | It matters again |
    Then the database answers "open" for:
      """
      select status from decisions
      """
    And the database answers "reopened, It matters again" for:
      """
      select kind, reason from decision_events order by id desc limit 1
      """

  Scenario: Reopening with a blank reason is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | "" |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-reopen-reason-error"
    And the database answers "dropped" for:
      """
      select status from decisions
      """

  Scenario: Reopening an open decision is turned away
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | Again |
    Then the decisions admin shows "[data-toast]" reading "That decision is open already"

  Scenario: The decision's task follows a new title and completes when the decision resolves
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | Sidekiq |
      | option[body]  | ""      |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a job queue |
      | decision[problem] | Jobs pile up     |
    Then the database answers "Resolve decision #1: Pick a job queue, open" for:
      """
      select title, status from tasks
      """
    When I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    Then the database answers "done" for:
      """
      select status from tasks
      """
    When I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | Load grew |
    Then the database answers "open" for:
      """
      select status from tasks
      """

  Scenario: The decision's task cancels when the decision drops and reopens when it reopens
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    Then the database answers "canceled" for:
      """
      select status from tasks
      """
    When I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | It matters again |
    Then the database answers "open" for:
      """
      select status from tasks
      """

  Scenario: The decision's task stays canceled when the decision resolves after I cancel it
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | Sidekiq |
      | option[body]  | ""      |
    And I post to the decisions admin at "/admin/tasks/1/cancel"
    And I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    Then the database answers "canceled" for:
      """
      select status from tasks
      """

  Scenario: The decision's task comes back at the end of the next list when I deleted it
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/tasks/1/delete"
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Earlier', 'next', 50)
      """
    And I post to the decisions admin at "/admin/decisions/1/reopen" with:
      | decision[reason] | It matters again |
    Then the database answers "Earlier | Resolve decision #1: Pick a queue" for:
      """
      select string_agg(title, ' | ' order by position) from tasks where list = 'next' and status = 'open'
      """

  Scenario: Completing, canceling or deleting the decision's task leaves the decision open
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a host    |
      | decision[problem] | The Pi is slow |
    And I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a font   |
      | decision[problem] | Text is small |
    And I post to the decisions admin at "/admin/tasks/1/complete"
    And I post to the decisions admin at "/admin/tasks/2/cancel"
    And I post to the decisions admin at "/admin/tasks/3/delete"
    Then the database answers "done, canceled" for:
      """
      select string_agg(status::text, ', ' order by id) from tasks
      """
    And the database answers "open, open, open" for:
      """
      select string_agg(status::text, ', ' order by id) from decisions
      """

  Scenario: The decision never touches a task I link by hand
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a queue |
      | decision[problem] | Jobs pile up |
    And I post to the decisions admin at "/admin/decisions/1/options" with:
      | option[title] | Sidekiq |
      | option[body]  | ""      |
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Ask ops', 'next', 9)
      """
    And I post to the decisions admin at "/admin/decisions/1/records" with:
      | record[other_kind] | task |
      | record[other_id]   | 2    |
    And I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a job queue |
      | decision[problem] | Jobs pile up     |
    And I post to the decisions admin at "/admin/decisions/1/resolve" with:
      | decision[option_id] | 1       |
      | decision[reason]    | It runs |
    Then the database answers "Resolve decision #1: Pick a job queue, done | Ask ops, open" for:
      """
      select string_agg(title || ', ' || status, ' | ' order by id) from tasks
      """

  Scenario Outline: The decision pages have no axe breaches
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    And the decision "Pick a queue" has the comment "Leaning on Sidekiq"
    And the decision "Pick a queue" carries the tag "queues"
    And a dropped decision "Gone" opened 1 hour ago
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Move the server', 'next', 1);
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1);
      """
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                                   |
      | /admin                                 |
      | /admin/decisions                       |
      | /admin/decisions?status=dropped        |
      | /admin/decisions/new                   |
      | /admin/decisions/1                     |
      | /admin/decisions/1?record_q=server     |
      | /admin/decisions/1/edit                |
      | /admin/decisions/2                     |
      | /admin/decisions/2/edit                |
      | /admin/tasks/1                         |
