Feature: Admin decision record links
  A decision's page lists the records linked to it and finds more to link.

  Background:
    Given I am signed in to the admin
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Move the server', 'next', 1), ('Order the rack', 'next', 2)
      """

  Scenario: A decision with no links says nothing is linked yet
    When I visit "/admin/decisions/1"
    Then the decisions admin shows ".record-links .hint" reading "Nothing linked yet."

  Scenario: The Linked section lists its tasks, each linking to its page with a remove form
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id)
        values ('task', 1, 'decision', 1), ('task', 2, 'decision', 1)
      """
    When I visit "/admin/decisions/1"
    Then the decisions admin's ".record-link-group:has-text('Tasks') a.record-link-title >> text=Move the server" has the href "/admin/tasks/1"
    And the decisions admin's ".record-link-group:has-text('Tasks') a.record-link-title >> text=Order the rack" has the href "/admin/tasks/2"
    And the decisions admin shows ".record-links form[action='/admin/records/decision/1/links/task/1/delete']"

  Scenario: The Linked section lists any other linked record
    Given a published post "On hosting" linked to the decision "Pick a host"
    When I visit "/admin/decisions/1"
    Then the decisions admin shows ".record-link-group:has-text('Posts') a" reading "On hosting"

  Scenario: The picker finds a task by its title and posts the link from the match
    When I visit "/admin/decisions/1?record_q=server"
    Then the decisions admin lists ".record-links .record-picker-target .record-link-title" as "Move the server"
    And the decisions admin's ".record-links form.record-picker-find" has the action "/admin/decisions/1"
    And the decisions admin shows ".record-links form[action='/admin/decisions/1/records'] button.record-picker-target"

  Scenario: The picker leaves out a task it already links to
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1)
      """
    When I visit "/admin/decisions/1?record_q=server"
    Then the decisions admin shows no ".record-picker-target"

  Scenario: Adding links ties several tasks, shows on the task's side and comes back to the decision
    When I post to the decisions admin at "/admin/decisions/1/records" with:
      | record[other_kind] | task |
      | record[other_id]   | 1    |
    Then the decisions admin lands on "/admin/decisions/1"
    And the decisions admin shows "[data-toast]" reading "Record linked"
    When I post to the decisions admin at "/admin/decisions/1/records" with:
      | record[other_kind] | task |
      | record[other_id]   | 2    |
    Then the database answers "1 | 2" for:
      """
      select string_agg(left_id::text, ' | ' order by left_id) from record_links
      where left_kind = 'task' and right_kind = 'decision' and right_id = 1
      """
    When I visit "/admin/tasks/1"
    Then the decisions admin's ".record-links a.record-link-title >> text=Pick a host" has the href "/admin/decisions/1"

  Scenario: Adding a link to a decision that is not there answers 404
    When I post to the decisions admin at "/admin/decisions/0/records" with:
      | record[other_kind] | task |
      | record[other_id]   | 1    |
    Then the decisions admin answers 404

  Scenario: Adding a task already linked says so beside the picker and writes nothing
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1)
      """
    When I post to the decisions admin at "/admin/decisions/1/records" with:
      | record[other_kind] | task   |
      | record[other_id]   | 1      |
      | record_q           | server |
    Then the decisions admin answers 422
    And the decisions admin shows "[data-decision-read='1']"
    And the decisions admin shows ".record-links #decision-1-record-other-id-error" reading "These two are already linked."
    And the decisions admin's "#decision-1-record-other-id" holds "server"
    And the database answers "1" for:
      """
      select count(*) from record_links
      """

  Scenario: Adding a record that is gone is refused
    When I post to the decisions admin at "/admin/decisions/1/records" with:
      | record[other_kind] | task   |
      | record[other_id]   | 999999 |
    Then the decisions admin shows ".record-links #decision-1-record-other-id-error" reading "That record is gone. Find another."

  Scenario: Removing a link clears it, comes back to the decision and says so
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1)
      """
    When I post to the decisions admin at "/admin/records/decision/1/links/task/1/delete"
    Then the decisions admin lands on "/admin/decisions/1"
    And the decisions admin shows "[data-toast]" reading "Link removed"
    And the database answers "0" for:
      """
      select count(*) from record_links
      """

  Scenario: Removing a link that is not there answers 404
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1)
      """
    When I post to the decisions admin at "/admin/records/decision/1/links/task/2/delete"
    Then the decisions admin answers 404

  Scenario: Deleting a linked task drops the link
    Given the database runs:
      """
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1)
      """
    When I post to the decisions admin at "/admin/tasks/1/delete"
    Then the database answers "0" for:
      """
      select count(*) from record_links
      """
