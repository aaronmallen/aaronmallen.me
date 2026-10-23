Feature: Admin decision timeline
  A decision's page keeps its comments in their own card and its events on a timeline, each in time order.

  Background:
    Given I am signed in to the admin
    And a decision "Pick a queue" with the problem "Jobs pile up"

  Scenario: A decision with no history says nothing has happened
    When I visit "/admin/decisions/1"
    Then the decisions admin shows ".timeline-card .hint" reading "Nothing has happened yet."

  Scenario: Comments and events each keep time order
    Given the decision "Pick a queue" has the option "Sidekiq"
    And the database runs:
      """
      insert into decision_comments (decision_id, body, created_at) values (1, 'Noon', now() - interval '22 hours');
      insert into decision_events (decision_id, kind, option_id, created_at)
        values (1, 'option_added', 1, now() - interval '23 hours');
      insert into decision_comments (decision_id, body, created_at) values (1, 'Ten', now() - interval '24 hours');
      insert into decision_events (decision_id, kind, created_at) values (1, 'edited', now() - interval '1439 minutes');
      """
    When I visit "/admin/decisions/1"
    Then the decisions admin lists ".decision-main .timeline > li" holding "Ten, Noon"
    And the decisions admin lists ".timeline-card .timeline > li" holding "Edited the decision, Added the option Sidekiq"

  Scenario: Another decision's comments and events stay off the page
    Given a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the comment "Elsewhere"
    And I post to the decisions admin at "/admin/decisions/2/drop" with:
      | decision[reason] | No need |
    When I visit "/admin/decisions/1"
    Then the decisions admin shows no ".timeline"

  Scenario: An edit while open shows no note
    When I post to the decisions admin at "/admin/decisions/1" with:
      | decision[title]   | Pick a queue      |
      | decision[problem] | Jobs pile up fast |
    And I visit "/admin/decisions/1"
    Then the decisions admin shows "[data-decision-event='edited']"
    And the decisions admin shows no "[data-decision-event='edited'] .markdown-body"

  Scenario: Every event shows on the page, oldest first, with its reason or note as Markdown
    When I post to the decisions admin at "/admin/decisions" with:
      | decision[title]   | Pick a host    |
      | decision[problem] | The Pi is slow |
    And I post to the decisions admin at "/admin/decisions/2/options" with:
      | option[title] | Fly |
      | option[body]  | ""  |
    And I post to the decisions admin at "/admin/decisions/2/comments" with:
      | comment[body] | Fly looks **cheap** |
    And I post to the decisions admin at "/admin/decisions/2/resolve" with:
      | decision[option_id] | 1              |
      | decision[reason]    | It is *cheap*  |
    And I post to the decisions admin at "/admin/decisions/2" with:
      | decision[title]   | Pick a host |
      | decision[problem] | Slower      |
      | decision[note]    | Timed it    |
    And I post to the decisions admin at "/admin/decisions/2/options/1" with:
      | option[title] | Fly.io  |
      | option[body]  | ""      |
      | option[note]  | Renamed |
    And I post to the decisions admin at "/admin/decisions/2/reopen" with:
      | decision[reason] | Prices went up |
    And I post to the decisions admin at "/admin/decisions/2/drop" with:
      | decision[reason] | Stayed on the Pi |
    And I visit "/admin/decisions/2"
    Then the decisions admin lists the data-decision-event of ".timeline > li" as "none, opened, option_added, resolved, edited, option_edited, reopened, dropped"
    And the decisions admin shows "[data-decision-event='option_added']" reading "Added the option Fly.io"
    And the decisions admin shows "[data-decision-event='resolved']" reading "Resolved it with Fly.io"
    And the decisions admin lists "[data-decision-event] .markdown-body" as "It is cheap, Timed it, Renamed, Prices went up, Stayed on the Pi"
    And the decisions admin lists "[data-decision-event='resolved'] .markdown-body em" as "cheap"
    And the decisions admin lists ".comment-body strong" as "cheap"

  Scenario: A comment shows its author and time, leaves out script and offers its forms
    Given the decision "Pick a queue" has the option "Sidekiq"
    And the database runs:
      """
      insert into decision_comments (decision_id, body, created_at) values (1, 'say **why**', '2026-09-07 17:30Z');
      insert into decision_comments (decision_id, body) values (1, '<script>alert(1)</script>');
      insert into decision_events (decision_id, kind, option_id) values (1, 'option_added', 1);
      """
    When I visit "/admin/decisions/1"
    Then the decisions admin shows "[data-decision-comment='1'] .comment-author" reading "Aaron Allen"
    And the decisions admin's "[data-decision-comment='1'] time" has the datetime "2026-09-07T12:30:00-05:00"
    And the decisions admin shows no ".comment-body script"
    And the decisions admin shows "[data-decision-comment='1'] details form[method='post'][action='/admin/decisions/1/comments/1'] textarea[name='comment[body]']"
    And the decisions admin shows "[data-decision-comment='1'] form[method='post'][action='/admin/decisions/1/comments/1/delete']"
    And the decisions admin shows "form[method='post'][action='/admin/decisions/1/comments'] textarea[name='comment[body]']"
    And the decisions admin shows no "[data-decision-read='1'] [class*='task-']"

  Scenario: Adding a comment trims it, says so and shows it
    When I post to the decisions admin at "/admin/decisions/1/comments" with:
      | comment[body] | "  Looked into it  " |
    Then the decisions admin lands on "/admin/decisions/1"
    And the decisions admin shows "[data-toast]" reading "Comment added"
    And the decisions admin lists ".comment-body" as "Looked into it"
    And the database answers "Looked into it" for:
      """
      select body from decision_comments
      """

  Scenario: A closed decision still takes a comment
    When I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |
    And I post to the decisions admin at "/admin/decisions/1/comments" with:
      | comment[body] | Still thinking |
    Then the database answers "Still thinking" for:
      """
      select body from decision_comments
      """

  Scenario: Adding a comment to a decision that is not there answers 404
    When I post to the decisions admin at "/admin/decisions/999999/comments" with:
      | comment[body] | Hello |
    Then the decisions admin answers 404

  Scenario: An empty comment is refused beside the field
    When I post to the decisions admin at "/admin/decisions/1/comments" with:
      | comment[body] | " " |
    Then the decisions admin answers 422
    And the database answers "0" for:
      """
      select count(*) from decision_comments
      """
    And the decisions admin shows "#decision-1-comment-body-error" reading "Write the comment first."

  Scenario: Editing a comment saves the new body and says so
    Given the decision "Pick a queue" has the comment "Before"
    When I post to the decisions admin at "/admin/decisions/1/comments/1" with:
      | comment[body] | After |
    Then the decisions admin shows "[data-toast]" reading "Comment saved"
    And the database answers "After" for:
      """
      select body from decision_comments
      """

  Scenario: Editing another decision's comment answers 404 and changes nothing
    Given a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the comment "Elsewhere"
    When I post to the decisions admin at "/admin/decisions/1/comments/1" with:
      | comment[body] | Changed |
    Then the decisions admin answers 404
    And the database answers "Elsewhere" for:
      """
      select body from decision_comments
      """

  Scenario: Editing a comment to nothing opens its form with the error and keeps the old body
    Given the decision "Pick a queue" has the comment "Before"
    When I post to the decisions admin at "/admin/decisions/1/comments/1" with:
      | comment[body] | " " |
    Then the decisions admin answers 422
    And the decisions admin shows "#decision-1-comment-1-body-error" reading "Write the comment first."
    And the decisions admin shows "[data-decision-comment='1'] details.comment-edit[open]"
    And the decisions admin shows no "#decision-1-comment-body-error"
    And the database answers "Before" for:
      """
      select body from decision_comments
      """

  Scenario: Deleting a comment removes it and says so, and a second delete answers 404
    Given the decision "Pick a queue" has the comment "Before"
    When I post to the decisions admin at "/admin/decisions/1/comments/1/delete"
    Then the decisions admin shows "[data-toast]" reading "Comment deleted"
    And the database answers "0" for:
      """
      select count(*) from decision_comments
      """
    When I post to the decisions admin at "/admin/decisions/1/comments/1/delete"
    Then the decisions admin answers 404
