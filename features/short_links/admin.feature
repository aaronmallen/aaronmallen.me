Feature: Short links in the admin
  The owner shortens links on the share host, finds and sorts them, renames, retargets and deletes them, and
  sees which destinations fail the nightly check.

  Background:
    Given I am signed in to the admin

  Scenario: The links tab sits under Publish beside Files and says when nothing is shortened
    When I visit "/admin/links"
    Then the publish tabs read "/admin/posts /admin/social /admin/files /admin/links"
    And I see "Nothing shortened yet. Paste a link above."
    And the page has no axe breaches in light or dark

  Scenario: A row shows the host, the destination, the clicks, the date and the share link
    Given these short links:
      | code     | destination                  | clicks | made                 |
      | talk-now | https://www.example.com/talk | 1204   | 2026-09-03T12:00:00Z |
    When I visit "/admin/links"
    Then the short link rows read "example.com"
    And I see "www.example.com/talk"
    And I see "1,204 clicks"
    And I see "made Sep 3, 2026"
    And I do not see "retargeted"
    And I see "shares.localhost/talk-now"
    And a copy button holds "http://shares.localhost/talk-now"
    And I see "1 short link on shares.localhost, 1,204 clicks in all."
    And the page has no axe breaches in light or dark

  Scenario: A titled row shows its title and when it was retargeted, and one click reads as a click
    Given these short links:
      | code     | destination                  | title   | clicks | retargeted |
      | talk-now | https://www.example.com/talk | My talk | 1      | 1 day ago  |
    When I visit "/admin/links"
    Then the short link rows read "My talk"
    And I see "retargeted"
    And I see "1 short link on shares.localhost, 1 click in all."

  Scenario: Links list newest or most clicked first, and search matches title, destination and code
    Given these short links:
      | code     | destination                    | title     | clicks | made                 |
      | gh       | https://github.com/aaronmallen |           | 9      | 2026-09-01T00:00:00Z |
      | the-deck | https://example.com/slides     |           | 1      | 2026-09-02T00:00:00Z |
      | rec      | https://example.org/           | Recording | 4      | 2026-09-03T00:00:00Z |
    When I visit "/admin/links"
    Then the short link rows read "Recording, example.com, github.com"
    When I visit "/admin/links?sort=clicks"
    Then the short link rows read "github.com, Recording, example.com"
    When I visit "/admin/links?search=record"
    Then the short link rows read "Recording"
    And I see "1 match"
    When I visit "/admin/links?search=github"
    Then the short link rows read "github.com"
    When I visit "/admin/links?search=deck"
    Then the short link rows read "example.com"
    When I visit "/admin/links?sort=clicks&search=example"
    Then the short link rows read "Recording, example.com"
    When I visit "/admin/links?search=example"
    And I pick the "most clicked" option
    Then I am on "/admin/links?search=example&sort=clicks"
    When I visit "/admin/links?search=nothing"
    Then I see "No links match."

  Scenario: Links page by fifteen
    Given these short links:
      | code | destination             | title   | made                 |
      | l0   | https://example.com/0   | link 0  | 2026-09-01T00:00:00Z |
      | l1   | https://example.com/1   | link 1  | 2026-09-02T00:00:00Z |
      | l2   | https://example.com/2   | link 2  | 2026-09-03T00:00:00Z |
      | l3   | https://example.com/3   | link 3  | 2026-09-04T00:00:00Z |
      | l4   | https://example.com/4   | link 4  | 2026-09-05T00:00:00Z |
      | l5   | https://example.com/5   | link 5  | 2026-09-06T00:00:00Z |
      | l6   | https://example.com/6   | link 6  | 2026-09-07T00:00:00Z |
      | l7   | https://example.com/7   | link 7  | 2026-09-08T00:00:00Z |
      | l8   | https://example.com/8   | link 8  | 2026-09-09T00:00:00Z |
      | l9   | https://example.com/9   | link 9  | 2026-09-10T00:00:00Z |
      | l10  | https://example.com/10  | link 10 | 2026-09-11T00:00:00Z |
      | l11  | https://example.com/11  | link 11 | 2026-09-12T00:00:00Z |
      | l12  | https://example.com/12  | link 12 | 2026-09-13T00:00:00Z |
      | l13  | https://example.com/13  | link 13 | 2026-09-14T00:00:00Z |
      | l14  | https://example.com/14  | link 14 | 2026-09-15T00:00:00Z |
      | l15  | https://example.com/15  | link 15 | 2026-09-16T00:00:00Z |
    When I visit "/admin/links?sort=clicks"
    Then the short link rows read "link 15, link 14, link 13, link 12, link 11, link 10, link 9, link 8, link 7, link 6, link 5, link 4, link 3, link 2, link 1"
    When I follow the next page of short links
    Then I am on "/admin/links?sort=clicks&page=2"
    When I visit "/admin/links?page=2"
    Then the short link rows read "link 0"
    When I visit "/admin/links?page=3"
    Then the server answers 404

  Scenario: The shorten form posts to the links route
    When I visit "/admin/links"
    Then the links page holds "form.link-new[action='/admin/links'][method='post'] [name='link[destination]']"
    And the links page holds "form.link-new [name='link[code]']"

  Scenario: Shortening a link makes a code, copies it, names it after its page and lists it
    Given the clipboard is watched
    And the web answers GET "http://203.0.113.20/talk" with:
      """
      <title>My talk</title>
      """
    When I visit "/admin/links"
    And I fill in the link "Long link" with " http://203.0.113.20/talk "
    And I click "Shorten"
    Then I see "Shortened · link copied"
    And the short link rows read "My talk"
    And the short_links table has a row with:
      | destination              | title   |
      | http://203.0.113.20/talk | My talk |
    And the clipboard holds "http://shares.localhost/1"
    And the short link "1" sends visitors to "http://203.0.113.20/talk"

  Scenario: Shortening with my own code, and a script gets the link back
    Given the web answers GET "http://203.0.113.20/talk" with:
      """
      <title>My talk</title>
      """
    And the web answers GET "http://203.0.113.20/deck" with:
      """
      <title>My deck</title>
      """
    When I visit "/admin/links"
    And I fill in the link "Long link" with "http://203.0.113.20/talk"
    And I fill in the link "Short code · optional" with "talk-now"
    And I click "Shorten"
    Then I see "Shortened"
    And the short_codes table has a row with:
      | code     |
      | talk-now |
    And the short link "talk-now" sends visitors to "http://203.0.113.20/talk"
    When a script shortens "http://203.0.113.20/deck" as "the-deck"
    Then that answers 201
    And the API answer holds:
      """
      {"link": "http://shares.localhost/the-deck", "message": "Shortened"}
      """

  Scenario: A page that will not answer leaves the host as the title
    Given the web answers GET "http://203.0.113.20/talk" with status 503
    When I visit "/admin/links"
    And I fill in the link "Long link" with "http://203.0.113.20/talk"
    And I click "Shorten"
    Then the short_links table has a row with:
      | destination              |
      | http://203.0.113.20/talk |
    When I visit "/admin/links"
    Then the short link rows read "203.0.113.20"

  Scenario Outline: Shortening refuses what it cannot take, keeps what I typed and copies nothing
    Given these short links:
      | code     | destination               |
      | talk-now | https://example.com/talk  |
    And the clipboard is watched
    When I visit "/admin/links"
    And I fill in the link "Long link" with "<destination>"
    And I fill in the link "Short code · optional" with "<code>"
    And I click "Shorten"
    Then I see "<error>"
    And nothing is copied
    And the short_links table holds 1 rows

    Examples:
      | destination               | code     | error                                                                         |
      | javascript:alert(1)       | new-one  | That doesn't look like a web link. It has to start with http:// or https://. |
      | https://example.com/other | talk-now | A file or another link already uses that code.                                |
      | https://example.com/other | no--way  | Use lowercase letters, numbers and single hyphens.                            |
      |                           |          | Paste a link to shorten.                                                      |

  Scenario: Shortening a link again names its code first, then makes a second
    Given these short links:
      | code     | destination              |
      | talk-now | http://203.0.113.20/talk |
    And the web answers GET "http://203.0.113.20/talk" with:
      """
      <title>My talk</title>
      """
    And the clipboard is watched
    When I visit "/admin/links"
    And I fill in the link "Long link" with "http://203.0.113.20/talk"
    And I click "Shorten"
    Then I see "Already shortened as shares.localhost/talk-now. Shorten again for a second code."
    And nothing is copied
    And the short_links table holds 1 rows
    When I click "Shorten"
    Then the short_links table holds 2 rows
    And I see "Shortened · link copied"

  Scenario: Shortening asks again when I change the link after the warning
    Given these short links:
      | code       | destination               |
      | talk-now   | https://example.com/talk  |
      | other-link | https://example.com/other |
    When I visit "/admin/links"
    And I fill in the link "Long link" with "https://example.com/talk"
    And I click "Shorten"
    And I fill in the link "Long link" with "https://example.com/other"
    And I click "Shorten"
    Then I see "Already shortened as shares.localhost/other-link. Shorten again for a second code."
    And the short_links table holds 2 rows

  Scenario: A row's chip copies its link
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    And the clipboard is watched
    When I visit "/admin/links"
    And I click "shares.localhost/talk-now"
    Then I see "Link copied"
    And the clipboard holds "http://shares.localhost/talk-now"

  Scenario: A row's drawer shows the link and copies it as markdown
    Given these short links:
      | code     | destination                  | clicks | made                 | last_clicked         |
      | talk-now | https://www.example.com/talk | 1      | 2026-09-03T12:00:00Z | 2026-09-05T12:00:00Z |
    And the clipboard is watched
    When I visit "/admin/links"
    Then the links page holds ".link-row-title a[href='/admin/links/1/edit'][data-dialog-open='link-1-drawer']"
    When I click "example.com"
    Then I see "made September 3, 2026"
    And I see "last clicked Sep 5, 2026"
    And a copy button holds "[example.com](http://shares.localhost/talk-now)"
    When I click "Copy as markdown"
    Then I see "Markdown copied"
    And the clipboard holds "[example.com](http://shares.localhost/talk-now)"
    And the page has no axe breaches in light or dark

  Scenario: A titled link copies its title as markdown, with brackets and backslashes escaped
    Given these short links:
      | code     | destination              | title               |
      | talk-now | https://example.com/talk | My [talk] \\ slides |
    When I visit "/admin/links"
    Then the short_links table has a row with:
      | title              |
      | My [talk] \\ slides |
    And a copy button holds "[My \[talk\] \\ slides](http://shares.localhost/talk-now)"

  Scenario: The drawer saves a new title and keeps text I closed it on
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    And the web answers GET "http://203.0.113.20/other" with:
      """
      <title>Other</title>
      """
    When I visit "/admin/links"
    And I click "example.com"
    And I fill in the link "Title" with "My talk"
    And I close the link drawer with Escape
    And I fill in the link "Long link" with "http://203.0.113.20/other"
    And I click "Shorten"
    Then the short link rows read "Other, example.com"
    When I click "example.com"
    Then the link field "Title" holds "My talk"
    When I click "Save"
    Then the short link rows read "Other, My talk"

  Scenario: The drawer asks before it deletes
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    When I visit "/admin/links"
    And I click "example.com"
    And I click "Delete link"
    Then I see "Delete shares.localhost/talk-now? Anyone following it gets a 404."
    When I click "Delete link"
    Then the short link rows read ""
    And the short_links table holds 0 rows

  Scenario: The edit page shows the form, saves a title and says so
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    When I visit "/admin/links/1/edit"
    Then the link field "Destination" holds "https://example.com/talk"
    And the link field "Short code" holds "talk-now"
    And the link field "Title" holds ""
    And I see "Where shares.localhost/talk-now sends people."
    And I see "The part after shares.localhost/. Save a new one and the old link stops working at once."
    And I see "Only you see it. Search and the markdown you copy use it."
    And the page has no axe breaches in light or dark
    When I fill in the link "Title" with "My talk"
    And I click "Save"
    Then I see "Link saved"
    And the short_links table has a row with:
      | title   |
      | My talk |
    When I visit "/admin/links?search=my talk"
    Then the short link rows read "My talk"
    And a copy button holds "[My talk](http://shares.localhost/talk-now)"

  Scenario: A missing link answers 404 on its edit page
    When I visit "/admin/links/9/edit"
    Then the server answers 404

  Scenario: Retargeting keeps the short link and fetches the new page's title
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    And the web answers GET "http://203.0.113.21/deck" with:
      """
      <title>My deck</title>
      """
    When I visit "/admin/links/1/edit"
    And I fill in the link "Destination" with "http://203.0.113.21/deck"
    And I click "Save"
    Then the short link "talk-now" sends visitors to "http://203.0.113.21/deck"
    And the short_links table has a row with:
      | title   |
      | My deck |
    When I visit "/admin/links"
    Then I see "Change where one points any time; the short link stays the same."
    And the short link rows read "My deck"

  Scenario: Retargeting a titled link keeps my title and fetches nothing
    Given these short links:
      | code     | destination              | title |
      | talk-now | https://example.com/talk | Mine  |
    When I visit "/admin/links/1/edit"
    And I fill in the link "Destination" with "http://203.0.113.21/deck"
    And I click "Save"
    Then I see "Link saved"
    And the short link rows read "Mine"

  Scenario: Clearing the title fetches it again
    Given these short links:
      | code     | destination              | title |
      | talk-now | http://203.0.113.20/talk | Old   |
    And the web answers GET "http://203.0.113.20/talk" with:
      """
      <title>My talk</title>
      """
    When I visit "/admin/links/1/edit"
    And I fill in the link "Title" with ""
    And I click "Save"
    Then the short_links table has a row with:
      | title   |
      | My talk |

  Scenario: A new code moves the link and the old one stops working
    Given these short links:
      | code     | destination              |
      | talk-now | http://203.0.113.20/talk |
    And the web answers GET "http://203.0.113.20/talk" with:
      """
      <title>My talk</title>
      """
    When I visit "/admin/links/1/edit"
    And I fill in the link "Short code" with "the-keynote"
    And I click "Save"
    Then the short link "the-keynote" sends visitors to "http://203.0.113.20/talk"
    And the short link "talk-now" answers 404

  Scenario Outline: Saving refuses what it cannot take, keeps what I typed and changes nothing
    Given these short links:
      | code       | destination               |
      | talk-now   | https://example.com/talk  |
      | other-link | https://example.com/other |
    And the short_codes table holds:
      | code     |
      | the-deck |
    When I visit "/admin/links/1/edit"
    And I fill in the link "Title" with "My talk"
    And I fill in the link "Destination" with "<destination>"
    And I fill in the link "Short code" with "<code>"
    And I click "Save"
    Then I see "<error>"
    And the link field "Short code" holds "<code>"
    And the link field "Title" holds "My talk"
    And the short_links table has a row with:
      | id | destination              | title |
      | 1  | https://example.com/talk | null  |

    Examples:
      | destination             | code       | error                                                                         |
      | javascript:alert(1)     | talk-now   | That doesn't look like a web link. It has to start with http:// or https://. |
      | https://example.org/new |            | Give it a code.                                                               |
      | https://example.org/new | other-link | A file or another link already uses that code.                                |
      | https://example.org/new | the-deck   | A file or another link already uses that code.                                |
      | https://example.org/new | no--way    | Use lowercase letters, numbers and single hyphens.                            |

  Scenario: Deleting a link frees its code and says so
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    When I visit "/admin/links/1/edit"
    And I click "Delete link"
    And I click "Delete link"
    Then I see "Link deleted"
    And the short_links table holds 0 rows
    And the short link "talk-now" answers 404
    When I visit "/admin/links"
    And I post to "/admin/links/9/delete" from the admin
    Then that answers 404

  Scenario: Failing destinations show in the filter, the lede and pills by how long they fail
    Given these short links:
      | code  | destination           | title | made                 |
      | dead  | https://dead.example/  | Dead  | 2026-09-01T00:00:00Z |
      | flaky | https://flaky.example/ | Flaky | 2026-09-02T00:00:00Z |
      | fine  | https://fine.example/  | Fine  | 2026-09-03T00:00:00Z |
      | fresh | https://fresh.example/ | Fresh | 2026-09-04T00:00:00Z |
    And the short_link_checks table holds:
      | short_link_id | url                    | failures | reason                  | checked_at           | first_failed_at      |
      | 1             | https://dead.example/  | 3        | 404 Not Found           | 2026-10-14T08:00:00Z | 2026-10-12T08:00:00Z |
      | 2             | https://flaky.example/ | 1        | 503 Service Unavailable | 2026-10-12T08:00:00Z | 2026-10-12T08:00:00Z |
      | 3             | https://fine.example/  | 0        | null                    | 2026-10-12T08:00:00Z | null                 |
    When I visit "/admin/links"
    Then I see "all 4"
    And I see "failing 2"
    And I see "2 destinations are failing."
    And the short link row "Dead" shows a pink pill reading "failing 3 nights"
    And I see "404 Not Found"
    And the short link row "Flaky" shows a orange pill reading "failing"
    And the short link row "Fine" shows a green pill reading "fine"
    And the short link row "Fresh" shows a plain pill reading "not checked yet"
    And the links page holds "dialog#link-1-drawer button[form='link-1-check']"
    When I visit "/admin/links?filter=failing"
    Then the short link rows read "Dead, Flaky"
    When I pick the "most clicked" option
    Then I am on "/admin/links?filter=failing&sort=clicks"
    When I visit "/admin/links?filter=failing&search=flaky"
    Then the short link rows read "Flaky"

  Scenario: The failing filter says when every destination answered
    Given these short links:
      | code | destination           | title |
      | fine | https://fine.example/ | Fine  |
    When I visit "/admin/links?filter=failing"
    Then I see "Every destination answered the last check."

  Scenario: The edit page shows the check, and Check again checks the destination now
    Given these short links:
      | code | destination              | title |
      | dead | http://203.0.113.22/gone | Dead  |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason        | checked_at           | first_failed_at      |
      | 1             | http://203.0.113.22/gone | 3        | 404 Not Found | 2026-10-14T08:00:00Z | 2026-10-12T08:00:00Z |
    And the web answers GET "http://203.0.113.22/gone" with status 200
    When I visit "/admin/links/1/edit"
    Then the links page holds "form#link-1-check[action='/admin/links/1/check']"
    And the links page holds "form[action='/admin/links/1'] input[name='link[destination]']"
    And I see "failing 3 nights"
    And I see "404 Not Found"
    And I see "first failed Oct 12, 2026"
    And I do not see "Find in post"
    When I press the check again button for "http://203.0.113.22/gone"
    Then I see "Checking that link"
    And I am on "/admin/links/1/edit"
    And the short_link_checks table has a row with:
      | short_link_id | failures | reason |
      | 1             | 0        | null   |
    When I post to "/admin/links/9/check" from the admin
    Then that answers 404

  Scenario: Retargeting forgets the last check
    Given these short links:
      | code | destination           | title |
      | dead | https://dead.example/ | Dead  |
    And the short_link_checks table holds:
      | short_link_id | url                   | failures | reason        | checked_at           | first_failed_at      |
      | 1             | https://dead.example/ | 3        | 404 Not Found | 2026-10-14T08:00:00Z | 2026-10-12T08:00:00Z |
    And the web answers GET "http://203.0.113.23/new" with:
      """
      <title>New</title>
      """
    When I visit "/admin/links/1/edit"
    And I fill in the link "Destination" with "http://203.0.113.23/new"
    And I click "Save"
    And I visit "/admin/links"
    Then the short link row "Dead" shows a plain pill reading "not checked yet"

  Scenario: A check landing updates the open links page
    Given these short links:
      | code | destination           | title |
      | dead | https://dead.example/ | Dead  |
    And the short_link_checks table holds:
      | short_link_id | url                   | failures | reason        | checked_at | first_failed_at |
      | 1             | https://dead.example/ | 3        | 404 Not Found | 1 day ago  | 1 day ago       |
    When I visit "/admin/links"
    And the short link check of "https://dead.example/" passes behind the page
    Then the short link row "Dead" shows a green pill reading "fine"
