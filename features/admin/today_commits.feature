Feature: Shipped today on the Today page
  The Shipped today card counts the commits pushed today, folds the list of them away and offers to import more
  from GitHub.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks
    And the Today page has a GitHub token

  Scenario: Shipped today names the repos and the latest commit under the count
    Given these commits for the Today page:
      | time  | repo              | message                     | additions | deletions |
      | 08:00 | aaronmallen/other | earlier                     | 1         | 0         |
      | 14:05 | aaronmallen/blog  | admin: add the commits card | 120       | 8         |
    When I visit "/admin"
    Then the Shipped today card reads "Across 2 repos. Latest: admin: add the commits card."

  Scenario: Shipped today counts one repo in the singular
    Given these commits for the Today page:
      | day       | repo              | message |
      | today     | aaronmallen/blog  | one     |
      | today     | aaronmallen/blog  | two     |
      | yesterday | aaronmallen/other | old     |
    When I visit "/admin"
    Then the Shipped today card reads "Across 1 repo. Latest: two."

  Scenario: Shipped today folds away a list of today's commits that each open their page
    Given these commits for the Today page:
      | sha                                      | time  | repo             | message                     | additions | deletions |
      | 9f8e7d6c5b4a39281706f5e4d3c2b1a098765432 | 14:05 | aaronmallen/blog | admin: add the commits card | 120       | 8         |
    When I visit "/admin"
    Then the commit list is folded away
    And the whole row of the commit "admin: add the commits card" opens its page
    And the commit "admin: add the commits card" reads "9f8e7d6 · blog · 14:05"
    And the commit "admin: add the commits card" adds "+120" and removes "−8"

  Scenario: Shipped today lists today's commits newest first by their subject
    Given these commits for the Today page:
      | day       | time  | message                                          |
      | today     | 08:00 | earlier                                          |
      | today     | 21:05 | later                                            |
      | today     | 12:00 | admin: add the card\n\nand say why it exists     |
      | yesterday | 23:00 | yesterday                                        |
    When I visit "/admin"
    Then the Shipped today card lists the commits:
      """
      later
      admin: add the card
      earlier
      """

  Scenario: Shipped today shows an empty state without commits today
    Given these commits for the Today page:
      | day       | message   |
      | yesterday | yesterday |
    When I visit "/admin"
    Then the Today side column holds the cards "Calendar, Shipped today, Agents"
    And the Shipped today card lists no commits
    And the Shipped today card says "Nothing pushed yet today."
    And the Shipped today card has no link "All of today's commits →"
    And the Shipped today card has no count

  Scenario: Shipped today counts today's commits with their additions and deletions
    Given these commits for the Today page:
      | day       | message | additions | deletions |
      | today     | one     | 120       | 8         |
      | today     | two     | 5         | 2         |
      | yesterday | old     | 99        | 99        |
    When I visit "/admin"
    Then the Shipped today count reads "2 commits+125 −10"
    And the Shipped today count matches the commit rows

  Scenario: Shipped today lists only the ten latest commits on a busy day and links to the rest
    Given these commits for the Today page:
      | time  | message |
      | 08:00 | at 8    |
      | 09:00 | at 9    |
      | 10:00 | at 10   |
      | 11:00 | at 11   |
      | 12:00 | at 12   |
      | 13:00 | at 13   |
      | 14:00 | at 14   |
      | 15:00 | at 15   |
      | 16:00 | at 16   |
      | 17:00 | at 17   |
      | 18:00 | at 18   |
      | 19:00 | at 19   |
    When I visit "/admin"
    Then the Shipped today card lists the commits:
      """
      at 19
      at 18
      at 17
      at 16
      at 15
      at 14
      at 13
      at 12
      at 11
      at 10
      """
    And the Shipped today count reads "12 commits+12 −0"
    And the commit list ends with the link "All of today's commits →" to today's commits in activity
    When I follow the link under the commit list
    Then the activity page mentions "at 8"
    And the activity page mentions "at 19"

  Scenario: The commit list reads never synced before the first import
    Given these commits for the Today page:
      | message                     |
      | admin: add the commits card |
    When I visit "/admin"
    Then the commit list says "never synced"
    And the Shipped today card has no standing sync line

  Scenario: The commit list gives the time the newest walk ran, not the edge it reached
    Given these commits for the Today page:
      | message                     |
      | admin: add the commits card |
    And the database runs:
      """
      insert into sync_states (kind, repo, synced_at, updated_at)
      values ('commits', 'aaronmallen/other', '2026-01-09 15:30:00+00', '2026-01-07 15:30:00+00'),
              ('commits', 'aaronmallen/blog', '2026-01-06 15:30:00+00', '2026-01-07 15:30:00+00');
      """
    When I visit "/admin"
    Then the commit list says "synced Jan 7, 2026, 09:30"
    And the commit list's sync time is "2026-01-07T09:30:00-06:00"

  Scenario: The commit list gives the Chicago clock time of a sync from today
    Given these commits for the Today page:
      | message                     |
      | admin: add the commits card |
    And the database runs:
      """
      insert into sync_states (kind, repo, synced_at, updated_at)
      values ('commits', 'aaronmallen/blog', now() - interval '1 day', now());
      """
    When I visit "/admin"
    Then the commit list says it synced today at the last sync's Chicago time

  Scenario: Import now is ready while a GitHub token is set
    When I visit "/admin"
    Then the Import now form posts to "/admin/commits/import" with a CSRF token
    And the Import now button sits in the card head
    And the Import now button reads "Import now" with a rotate icon that holds still
    And the Import now button hides "Importing…" with a spinning icon
    And the Import now button is enabled
    And the Shipped today card gives no hint

  Scenario: Import now waits for a GitHub token
    Given the database runs:
      """
      delete from service_connections where provider = 'github';
      """
    When I visit "/admin"
    Then the Import now button is disabled
    And the Shipped today card hints "GitHub isn't connected, so the import can't run."
