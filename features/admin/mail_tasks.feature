Feature: Admin mail makes tasks
  Make a task turns a thread into a task linked back to it, and can archive
  the thread on the way.

  Background:
    Given I am signed in to the admin

  Scenario: The task dialog offers a title from the subject and saves the task
    Given the mail threads:
      | subject                  |
      | Re: Fwd: Lunch on Friday |
    When I visit the mail page "/admin/mail?folder=inbox&show=all&thread=#[Re: Fwd: Lunch on Friday]"
    And I make a task from the mail reader
    Then the mail task dialog offers the title "Lunch on Friday" on the lists "today, next, someday" and archives
    And the mail task dialog says "The task keeps a link back to this thread."
    And the page has no axe breaches in light or dark
    When I save the mail task on "someday" without archiving
    Then the mail page address is "/admin/mail?folder=inbox&show=all&thread=#[Re: Fwd: Lunch on Friday]#read-#[Re: Fwd: Lunch on Friday]"
    And the task "Lunch on Friday" sits on "someday" linked to the mail thread "Re: Fwd: Lunch on Friday"
    And the mail thread "Re: Fwd: Lunch on Friday" is now unarchived

  Scenario: Making a task archives the thread when asked and names the task by its label
    Given the mail threads:
      | subject                  |
      | Re: Fwd: Lunch on Friday |
    When I post to the mail route "/admin/mail/#[Re: Fwd: Lunch on Friday]/task" with:
      """
      folder=inbox
      task[title]=Book lunch
      task[list]=next
      task[archive]=1
      """
    Then the mail thread "Re: Fwd: Lunch on Friday" is now archived
    And the mail toast says "Made task 1"
    When I post to the mail route "/admin/mail/#[Re: Fwd: Lunch on Friday]/task" with:
      """
      folder=inbox
      task[title]=Again
      task[list]=next
      """
    Then the mail toast says "This thread already has a task"
    And mail made 0 tasks called "Again"

  Scenario: Once a thread has a task, the reader, the row and the task link to each other
    Given the mail threads:
      | subject                  |
      | Re: Fwd: Lunch on Friday |
    When I post to the mail route "/admin/mail/#[Re: Fwd: Lunch on Friday]/task" with:
      """
      folder=inbox
      task[title]=Book lunch
      task[list]=next
      """
    And I visit the mail page "/admin/mail?folder=all&thread=#[Re: Fwd: Lunch on Friday]"
    Then the mail actions do not offer "Make a task"
    And the mail reader shows a link "Task #1" to "/admin/tasks/1"
    And the mail row "Re: Fwd: Lunch on Friday" shows "task #1"
    When I visit "/admin/tasks/1"
    Then the page has no axe breaches in light or dark
    Then the page links "Re: Fwd: Lunch on Friday" to the mail page "/admin/mail?folder=all&thread=#[Re: Fwd: Lunch on Friday]#read-#[Re: Fwd: Lunch on Friday]"

  Scenario: Two tabs that make a task at once make one task
    Given the mail threads:
      | subject |
      | Lunch   |
    When two tabs make a task from the mail thread "Lunch" at once
    Then mail made 1 task called "Book lunch"

  Scenario: Making a task needs a title and a thread that still exists
    Given the mail threads:
      | subject |
      | Lunch   |
    When I post to the mail route "/admin/mail/#[Lunch]/task" with:
      """
      folder=inbox
      task[title]=
      """
    Then the mail toast says "Give the task a title"
    And the mail thread "Lunch" has no task
    When I post to the mail route "/admin/mail/999999/task" with:
      """
      task[title]=Book lunch
      """
    Then the mail answer has status 404

  Scenario: Making a task on a Gmail thread archives it in Gmail too
    Given the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the mail threads:
      | subject | account            | gmail id |
      | Taken   | aaron@work.example | t1       |
      | Refused | aaron@work.example | refused  |
    And Gmail takes changes to the mail threads "t1"
    And Gmail refuses changes to the mail thread "refused"
    When I post to the mail route "/admin/mail/#[Taken]/task" with:
      """
      task[title]=Reply
      task[list]=next
      task[archive]=1
      """
    Then Gmail received POST "/users/me/threads/t1/modify" holding '{"removeLabelIds":["INBOX"]}'
    And the mail thread "Taken" is now archived
    When I post to the mail route "/admin/mail/#[Refused]/task" with:
      """
      task[title]=Reply again
      task[list]=next
      task[archive]=1
      """
    Then the mail toast says "Made task 2 · Gmail refused to archive the thread"
    And the mail thread "Refused" is now unarchived
