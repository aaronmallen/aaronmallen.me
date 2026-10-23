Feature: Admin journal paging
  The journal shows about a hundred entries a page, finishing the day it stops on, and links to older and newer
  pages with the search kept. Entries are named d<days back>e<number>.

  Background:
    Given I am signed in to the admin
    And the journal holds numbered entries:
      | days back | count |
      | 0         | 50    |
      | 1         | 100   |
      | 2         | 50    |
      | 3         | 50    |
      | 5         | 50    |

  Scenario: The first page stops near the page size, finishes its last day and links only to older entries
    When I visit "/admin/journal"
    Then the journal shows the days "{today}, {today-1}"
    And the journal page holds 100 of ".journal-day:has(time[datetime='{today-1}']) .journal-entry-body"
    And the journal's older link goes to "/admin/journal?to={today-2}"
    And the journal has no newer link

  Scenario: The older page shows the older days and links a page's worth of entries back
    When I open the journal page "/admin/journal?to={today-2}"
    Then the journal shows the days "{today-2}, {today-3}"
    And the journal's newer link goes to "/admin/journal?to={today-1}"

  Scenario: A page with a page or less newer links back to the newest page
    When I open the journal page "/admin/journal?to={today-1}"
    Then the journal's newer link goes to "/admin/journal"

  Scenario: The oldest day links to no older page
    When I open the journal page "/admin/journal?to={today-5}"
    Then the journal shows the days "{today-5}"
    And the journal has no older link

  Scenario: Paging keeps the search in the links and pages what the search finds
    When I visit "/admin/journal?q=d"
    Then the journal's older link goes to "/admin/journal?q=d&to={today-2}"
    When I visit "/admin/journal?q=d1e17"
    Then the journal entries read "d1e17"

  Scenario: The sub-line counts every entry, word and day written, not just the page
    When I visit "/admin/journal"
    Then the journal page shows ".page-head-sub" holding "300 entries · 300 words"
    And the journal page shows ".page-head-sub" holding "wrote on 5 of the last 30 days"

  Scenario Outline: A day of <day> reads as the newest page
    When I visit "/admin/journal?to=<day>"
    Then the journal shows the days "{today}, {today-1}"

    Examples:
      | day            |
      | soon           |
      | 99999999-01-01 |
      | -4800-01-01    |

  Scenario: One page that holds every entry draws no pager
    Given the database runs:
      """
      delete from journal_entries where id > 80
      """
    When I visit "/admin/journal"
    Then the journal page lacks "nav.pager"

  Scenario: Paging newer then older past a crowded day returns to each older page
    Given the database runs:
      """
      delete from journal_entries
      """
    And the journal holds numbered entries:
      | days back | count |
      | 0         | 50    |
      | 1         | 150   |
      | 2         | 50    |
      | 3         | 100   |
      | 4         | 50    |
      | 6         | 50    |
    When I follow the journal's older links to the end
    Then each older journal page comes back after paging newer then older
    And paging newer from the oldest journal page shows the days "{today}, {today-1}, {today-2}, {today-3}, {today-4}, {today-6}"

  Scenario: Paging newer past a crowded day shows the next day when the day past it fills a page
    Given the database runs:
      """
      delete from journal_entries
      """
    And the journal holds numbered entries:
      | days back | count |
      | 0         | 50    |
      | 1         | 150   |
      | 2         | 50    |
      | 3         | 100   |
      | 4         | 50    |
      | 6         | 50    |
    When I open the journal page "/admin/journal?to={today-3}"
    And I follow the journal's newer link
    Then the journal shows the days "{today-2}, {today-3}"
