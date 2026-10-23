Feature: Today's sprint
  The Today page leads with today's sprint. The headline counts what is left, the panel lists the open tasks, folds
  away what is done and lets the owner pull more in from a list.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks

  Scenario: Today puts the day and time over the headline
    When I visit "/admin"
    Then the Today kicker shows the day and the time

  Scenario: An empty sprint says nothing is planned and holds nothing
    When I visit "/admin"
    Then the Today headline reads "Nothing planned yet."
    And the Today lede reads "What do you want to get done today? Anything still open tonight rolls into tomorrow."
    And the sprint says "Nothing in today's sprint yet. Pull a task in from a list below."
    And the sprint has no progress bar
    And the sprint offers no capture row
    And the pools are open
    And the sprint panel comes first in the main column
    And the sprint panel is titled "Today's sprint"
    And the sprint panel links "all tasks →" to "/admin/tasks"
    And the Today page links "Plan tomorrow" to "/admin/tasks?filter=upcoming"

  Scenario: A task still open at night rolls into the next day, as the empty lede says
    Given the database runs:
      """
      insert into sprints (sprint_date) values ((now() at time zone 'America/Chicago')::date - 1);
      insert into tasks (title, sprint_id, position) select 'Ship the panel', id, 1 from sprints
      where sprint_date = (now() at time zone 'America/Chicago')::date - 1;
      """
    When the sprint roll over job runs
    And I visit "/admin"
    Then the Today lede says "Up next: Ship the panel, carried over 1 day"

  Scenario: The headline counts one thing left
    Given today's sprint plans "Ship the panel, Read the design" with 1 done
    When I visit "/admin"
    Then the Today headline reads "One thing left."

  Scenario: The headline counts the things left
    Given today's sprint plans "Ship the panel, Read the design, Email the accountant"
    When I visit "/admin"
    Then the Today headline reads "3 things left."

  Scenario: The headline calls the sprint clear when everything is done
    Given today's sprint plans "Ship the panel, Read the design" with 2 done
    When I visit "/admin"
    Then the Today headline reads "Sprint clear."
    And the Today lede reads "All 2 done. Pull something from next, or stop for the day."

  Scenario: A sprint with work done names what is next and how much is done
    Given today's sprint plans "Ship the panel, Read the design" with 1 done
    When I visit "/admin"
    Then the Today lede says "Up next: Read the design"
    And the Today lede ends with "1 of 2 done."
    And the sprint lists the open tasks "Read the design"
    And the sprint folds "Ship the panel" away under "1 done today"
    And the sprint progress bar is "50%" full
    And the sprint progress bar is named "Sprint progress" from 0 to 2 at 1
    And the sprint notes "1 of 2 done"

  Scenario: The lede names the task in progress before the rest
    Given today's sprint plans "Ship the panel, Read the design"
    And the database runs:
      """
      update tasks set status = 'in_progress' where title = 'Read the design';
      """
    When I visit "/admin"
    Then the Today lede says "You're in the middle of Read the design"

  Scenario: The lede says how long the lead task has carried over
    Given today's sprint plans "Ship the panel"
    And the database runs:
      """
      update tasks set carried_count = 2 where title = 'Ship the panel';
      """
    When I visit "/admin"
    Then the Today lede says "Up next: Ship the panel, carried over 2 days"

  Scenario: A canceled task stays out of the open rows and out of what is left
    Given today's sprint plans "Ship the panel, Read the design"
    And today's sprint holds the canceled task "Dropped"
    When I visit "/admin"
    Then the sprint lists the open tasks "Ship the panel, Read the design" in some order
    And the Today headline reads "2 things left."

  Scenario: The sprint is clear when what is left was canceled
    Given today's sprint plans "Ship the panel" with 1 done
    And today's sprint holds the canceled task "Dropped"
    When I visit "/admin"
    Then the Today headline reads "Sprint clear."

  Scenario: A sprint with everything done counts what was finished
    Given today's sprint plans "Ship the panel" with 1 done
    When I visit "/admin"
    Then the sprint says something with "1 finished"

  Scenario: Each open task leads with its key and ends with a pen that edits it from Today
    Given today's sprint plans "Ship, Read"
    When I visit "/admin"
    Then each open sprint task leads with its task number
    And the sprint task "Ship" ends with a pen that edits it from Today

  Scenario: A sprint task counts its comments in its meta line
    Given today's sprint plans "Ship the panel, Read the design"
    And the database runs:
      """
      insert into task_comments (task_id, body) select id, 'one' from tasks where title = 'Ship the panel';
      insert into task_comments (task_id, body) select id, 'two' from tasks where title = 'Ship the panel';
      """
    When I visit "/admin"
    Then the sprint task "Ship the panel" counts "2" comments
    And the sprint task "Read the design" shows no comment count

  Scenario: A sprint with nothing done folds nothing away and offers no capture row
    Given today's sprint plans "Ship the panel"
    When I visit "/admin"
    Then the sprint folds nothing away as done
    And the sprint offers no capture row

  Scenario: The sprint completes a task from its hover bar and comes back to Today
    Given today's sprint plans "Ship the panel"
    When I visit "/admin"
    And I send the "Done" form on the sprint task "Ship the panel"
    Then the Today page sends me to "/admin"
    And the database answers "done" for:
      """
      select status from tasks where title = 'Ship the panel'
      """

  Scenario: Finishing a task from the panel comes back to Today
    Given today's sprint plans "Ship the panel"
    When I visit "/admin"
    And I post "/admin/tasks/1/complete" from the Today page with "filter=today&origin=today"
    Then the Today post sends me to "/admin"

  Scenario: The pools fold away under the sprint's tasks and keep Today when switching
    Given today's sprint plans "Ship the panel"
    And the Today pool next holds "Email the accountant"
    When I visit "/admin"
    Then the pools are folded away under "Pull from a list"
    And the pools list "Email the accountant"
    And each pool row leads with its task number
    And the pool tabs link to "/admin?pool=next, /admin?pool=someday, /admin?pool=external"

  Scenario: Pulling from the pools under the sprint's tasks adds the task to today and comes back to Today
    Given today's sprint plans "Ship the panel"
    And the Today pool next holds "Email the accountant"
    When I visit "/admin"
    And I pull "Email the accountant" into today from the pools
    Then the Today page sends me to "/admin?pool=next"
    And the database answers "Email the accountant, Ship the panel" for:
      """
      select string_agg(title, ', ' order by title) from tasks
      where sprint_id = (select id from sprints where sprint_date = (now() at time zone 'America/Chicago')::date)
      """

  Scenario: Pulling a task in from a pool comes back to that pool
    Given the Today pool someday holds "Learn Elixir"
    When I visit "/admin?pool=someday"
    And I pull "Learn Elixir" into today from the pools
    Then the Today page sends me to "/admin?pool=someday"

  Scenario: Pulling a task in without a pool comes back to Today
    Given the Today pool next holds "Email the accountant"
    When I visit "/admin"
    And I post "/admin/tasks/1/move/today" from the Today page with "origin=today"
    Then the Today post sends me to "/admin"

  Scenario: The external pool links GitHub and Linear issues
    Given today's sprint plans "Ship the panel"
    And the Today pool external holds "Fix the bug, Ship the release"
    And the database runs:
      """
      insert into task_sources (task_id, provider, remote_id, url)
      select id, 'github', 'I_42', 'https://github.com/aaronmallen/aaronmallen.me/issues/42' from tasks where title = 'Fix the bug';
      insert into task_sources (task_id, provider, remote_id, url)
      select id, 'linear', 'lin-1', 'https://linear.app/acme/issue/ABC-123/ship-the-release' from tasks where title = 'Ship the release';
      """
    When I visit "/admin?pool=external"
    Then only the "external" pool is drawn
    And the pools link "aaronmallen/aaronmallen.me#42" to "https://github.com/aaronmallen/aaronmallen.me/issues/42"
    And the pools link "acme/ABC-123" to "https://linear.app/acme/issue/ABC-123/ship-the-release"

  Scenario: An empty sprint counts every pool and says which pool is empty
    When I visit "/admin"
    Then the pool tabs read "next · 0, someday · 0, external · 0"
    And the pool tabs link to "/admin?pool=next, /admin?pool=someday, /admin?pool=external"
    And the sprint says "Nothing in next yet."

  Scenario: An empty sprint pulls from someday when that pool is asked for
    Given the Today pool next holds "Email the accountant"
    And the Today pool someday holds "Learn Elixir"
    When I visit "/admin?pool=someday"
    Then the pool tabs read "next · 1, someday · 1, external · 0"
    And the pools list "Learn Elixir"

  Scenario: A pool shows one page of tasks and counts them all
    Given the database runs:
      """
      insert into tasks (title, list, position) select 'Task ' || n, 'next', n from generate_series(1, 101) n;
      """
    When I visit "/admin"
    Then the pools show 100 tasks
    And the pool tabs read "next · 101, someday · 0, external · 0"

  Scenario: Today claims today's sprint as it loads
    Given the database runs:
      """
      delete from sprints;
      """
    When I visit "/admin"
    Then the database answers "1" for:
      """
      select count(*) from sprints where sprint_date = (now() at time zone 'America/Chicago')::date
      """

  Scenario: Today carries yesterday's open work into today's sprint as it loads
    Given the database runs:
      """
      insert into sprints (sprint_date) values ((now() at time zone 'America/Chicago')::date - 1);
      insert into tasks (title, sprint_id, position) select 'Read the design', id, 1 from sprints
      where sprint_date = (now() at time zone 'America/Chicago')::date - 1;
      """
    When I visit "/admin"
    Then the sprint lists the open tasks "Read the design"
    And the database answers "1" for:
      """
      select count(*) from tasks join sprints on sprints.id = tasks.sprint_id
      where title = 'Read the design' and sprint_date = (now() at time zone 'America/Chicago')::date
      """

  Scenario: The Create Task button opens a dialog on today's list, with a page to fall back on
    When I visit "/admin"
    Then the Create Task button links to "/admin/tasks/new?origin=today" and opens the dialog "task-create"
    And the Create Task dialog posts to "/admin/tasks"
    And the "dialog" task form starts on the list "today" from "today"

  Scenario: A task from the Create Task dialog goes straight into today and back to Today
    When I visit "/admin"
    And I send the Create Task dialog with the title "Ship the panel"
    Then the Today page sends me to "/admin"
    And the database answers "Ship the panel" for:
      """
      select title from tasks
      where sprint_id = (select id from sprints where sprint_date = (now() at time zone 'America/Chicago')::date)
      """

  Scenario: A task from Today with no title says what is missing and keeps the way back
    When I visit "/admin"
    And I send the Create Task dialog with the title ""
    Then the Today post answers 422
    And the Today task form says "Write the task down first."
    And the "page" task form starts on the list "today" from "today"
