Feature: Commits
  The admin shows each imported commit on a page of its own, and the Today
  card queues an import. The API and MCP read the same commit.

  Scenario: The commit page shows the whole commit from the database
    Given I am signed in to the admin
    And a commit "feed fix" with:
      | sha       | abc1234000000000000000000000000000000000  |
      | repo      | aaronmallen/sai                           |
      | branch    | spike                                     |
      | message   | admin: add the view\n\nfirst para\n\nsecond para |
      | additions | 12                                        |
      | deletions | 3                                         |
    And the commit "feed fix" links to the task "Move the server"
    When I open the commit page for "feed fix"
    Then the GitHub record heads with "admin: add the view"
    And the GitHub record kicker reads "Commit abc1234"
    And the GitHub record subline reads "aaronmallen/sai · spike · Mar 2, 2026 at 14:05"
    And the GitHub record stats read "Added +12, Removed −3, Commit abc1234"
    And the GitHub record body shows the p items "first para, second para"
    And the GitHub record lists the linked task "Move the server" beside it
    And the GitHub record links back to the activity
    And the GitHub record links to "https://github.com/aaronmallen/sai/commit/abc1234000000000000000000000000000000000"
    And GitHub received no GET "/repos/aaronmallen/sai/commits/abc1234000000000000000000000000000000000"
    And the page has no axe breaches in light or dark

  Scenario: The commit page renders the body as Markdown and links out remote images
    Given I am signed in to the admin
    And a commit "notes" with:
      | message | subject\n\n- one\n- two\n\n![shot](https://example.com/shot.png) ![own](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png) |
    When I open the commit page for "notes"
    Then the GitHub record body shows the li items "one, two"
    And the GitHub record body links "shot" to "https://example.com/shot.png"
    And the GitHub record body shows the image "/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png" as "own"
    And the GitHub record body shows no image "https://example.com/shot.png"

  Scenario: The commit page says so when the subject is the whole message
    Given I am signed in to the admin
    And a commit "short" with:
      | message | admin: add the view |
    When I open the commit page for "short"
    Then the GitHub record says "Nothing beyond the subject line."

  Scenario: A visitor who has not signed in sees no commit
    Given a commit "payroll" with:
      | repo    | employer/payroll                          |
      | message | fix the rate table\n\nfor the March run |
    When I open the commit page for "payroll"
    Then I am sent to sign in
    And I do not see "employer/payroll"
    And I do not see "for the March run"

  Scenario: The commit page answers 404 for a commit that is not there
    Given I am signed in to the admin
    Then the GitHub record page at "/admin/commits/999999" answers with status 404

  Scenario: The API reads a commit with its whole message and links
    Given I am signed in to the admin
    And an API token
    And a commit "feed fix" with:
      | message   | fix the feed\n\nthe body runs on |
      | additions | 12                               |
      | deletions | 3                                |
    And the commit "feed fix" links to the task "Move the server"
    When I read the commit "feed fix" through the API
    Then the API answers 200
    And the API answer holds "the body runs on"
    And the API answer holds "\"sha\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
    And the API answer holds "\"date\":\"2026-03-02\",\"time\":\"14:05\",\"additions\":12,\"deletions\":3"
    And the API answer holds "\"record_links\":{\"task\":[{"
    And the API answer holds "\"title\":\"Move the server\""

  Scenario: The API and read_commit answer the same commit
    Given I am signed in to the admin
    And an API token
    And an MCP client connected with the scopes "read"
    And a commit "feed fix" with:
      | message | fix the feed\n\nthe body runs on |
    And the commit "feed fix" links to the task "Move the server"
    Then the API read of the commit "feed fix" matches the MCP tool "read_commit", less the untrusted marks

  Scenario: The import button queues an import and returns to Today
    Given I am signed in to the admin
    And GitHub holds a token for the commit import
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    When I visit "/admin"
    Then nothing on the page animates for the commit import
    When I click "Import now"
    Then I see "Import queued · new commits show on the card shortly"
    And I am back on Today after the commit import
    And GitHub received POST "/graphql"
    And the commit card shows no commits
    And the commit import button reads "Import now" and is enabled
    And nothing on the page animates for the commit import
    And the page has no axe breaches in light or dark

  Scenario: The import button reads Importing and spins only its icon while the form submits
    Given I am signed in to the admin
    And GitHub holds a token for the commit import
    When I visit "/admin"
    And I hold the commit import form
    And I click "Import now"
    Then the commit import button reads "Importing…" and is disabled
    And no commit import button reads "Import now"
    And only the commit import icon spins

  Scenario: The import button stays off until GitHub is connected
    Given I am signed in to the admin
    When I visit "/admin"
    Then the commit import button reads "Import now" and is disabled
    And I see "GitHub isn't connected"
    And nothing on the page animates for the commit import
    When I force the disabled commit import
    Then I see "Connect GitHub first."
    And no commit import reaches GitHub

  Scenario: An import without a CSRF token or a session queues nothing
    Given I am signed in to the admin
    And GitHub holds a token for the commit import
    Then a commit import posted to "/admin/commits/import" signed-in answers with status 403
    And a commit import posted to "/admin/commits/import" signed-out answers with status 403
    And no commit import reaches GitHub

  Scenario: The old backfill page is gone
    Given I am signed in to the admin
    And GitHub holds a token for the commit import
    Then the GitHub record page at "/admin/commits/backfill" answers with status 404
    And a commit import posted to "/admin/commits/backfill" signed-in answers with status 404
    And a commit import posted to "/admin/commits/backfill/clear" signed-in answers with status 404
    And a commit import posted to "/admin/commits/backfill/stop" signed-in answers with status 404
