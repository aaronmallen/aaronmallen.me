Feature: Admin activity paging
  The activity shows about a hundred events a page, finishing the day it stops on, and links to the older and
  newer pages with the same filters.

  Background:
    Given I am signed in to the admin

  Scenario: The activity's first page stops near the page size and finishes the day it is on
    Given 50 activity commits "today" on today
    And 50 activity commits "yesterday one" on yesterday
    And 50 activity commits "yesterday two" on yesterday
    And 50 activity commits "three days ago" on 3 days ago
    And 50 activity commits "twenty days ago" on 20 days ago
    When I open the activity with "from={today-29}&to={today}"
    Then the activity days read "today | yesterday"
    And the activity page has ".page-head-sub" reading "250 events across 4 days"
    And the activity counts 250 for "Commits"
    And the activity page has no "a.pager-link[rel='prev']"
    And the activity page has "nav.pager a.pager-link[rel='next'][href^='/admin/activity?']" reading "Older"

  Scenario: The activity's older page shows the rest of the range and links back to the first
    Given 50 activity commits "today" on today
    And 50 activity commits "yesterday one" on yesterday
    And 50 activity commits "yesterday two" on yesterday
    And 50 activity commits "three days ago" on 3 days ago
    And 50 activity commits "twenty days ago" on 20 days ago
    When I open the activity with "from={today-29}&to={today}"
    And I follow the activity's older link
    Then the activity rows read "three days ago × 50 | twenty days ago × 50"
    And the activity page has "#activity-from[value='{today-29}']"
    And the activity page has "#activity-to[value='{today}']"
    And the activity page has no "a.pager-link[rel='next']"
    And the activity's newer link leaves out "day="
    When I follow the activity's newer link
    Then the activity rows read "today × 50 | yesterday one × 50 | yesterday two × 50" in any order
    And the activity days read "today | yesterday"

  Scenario: The activity keeps the filters on the older page
    Given 50 activity commits "today" on today
    And 50 activity commits "yesterday one" on yesterday
    And 50 activity commits "yesterday two" on yesterday
    And 50 activity commits "three days ago" on 3 days ago
    When I open the activity with "from={today-29}&to={today}&q=o"
    Then the activity's older link holds "q=o"

  Scenario: The activity links from the third page back to the page in between, and from there to the first
    Given 100 activity commits "today" on today
    And 100 activity commits "yesterday one" on yesterday
    And 100 activity commits "yesterday two" on yesterday
    And 100 activity commits "three days ago" on 3 days ago
    And 100 activity commits "twenty days ago" on 20 days ago
    When I open the activity with "from={today-29}&to={today}"
    And I follow the activity's older link
    And I follow the activity's older link
    And I follow the activity's newer link
    Then the activity rows read "yesterday one × 100 | yesterday two × 100" in any order
    And the activity's newer link leaves out "day="

  Scenario: The activity links from a day past the oldest event to the last page that holds one
    Given 50 activity commits "today" on today
    And 50 activity commits "yesterday one" on yesterday
    And 50 activity commits "yesterday two" on yesterday
    And 50 activity commits "three days ago" on 3 days ago
    And 50 activity commits "twenty days ago" on 20 days ago
    When I open the activity with "from={today-29}&to={today}&day={today-25}"
    And I follow the activity's newer link
    Then the activity rows read "three days ago × 50 | twenty days ago × 50"

  Scenario Outline: The activity starts at the end of the range for a day of <day>
    Given 50 activity commits "today" on today
    And 50 activity commits "yesterday one" on yesterday
    And 50 activity commits "yesterday two" on yesterday
    When I open the activity with "from={today-29}&to={today}&day=<day>"
    Then the activity rows include "today"

    Examples:
      | day            |
      | {today+3}      |
      | soon           |
      | 99999999-01-01 |

  Scenario: The activity's older link points past a gap to the day before the last one it answered
    Given 100 activity commits "today" on today
    And 100 activity commits "five days ago" on 5 days ago
    When I open the activity with "from={today-29}&to={today}"
    Then the activity rows read "today × 100"
    And the activity's older link holds "day={today-1}"

  Scenario: The activity shows the whole last day when it holds the rest of the range
    Given 150 activity commits "yesterday" on yesterday
    When I open the activity with "from={today-29}&to={today}"
    Then the activity shows 150 rows
    And the activity page has no "a.pager-link[rel='next']"

  Scenario: The activity offers no older link when the page ends on the first day of the range
    Given 100 activity commits "first day" on 29 days ago
    And 50 activity commits "second day" on 28 days ago
    When I open the activity with "from={today-29}&to={today}"
    Then the activity shows 150 rows
    And the activity page has no "a.pager-link[rel='next']"
