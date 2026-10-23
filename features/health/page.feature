Feature: Health page
  The admin's health page lines up sleep, heart rate and work by day, flags the days off the owner's usual, and says
  which agents can read it.

  Background:
    Given I am signed in to the admin

  Scenario: The health page opens on today with a 30 day span
    When I open the health page
    Then the health page sits among the Insights tabs
    And the health spans offered are "14d 30d 90d" with "30d" current
    And the health grid draws 30 columns
    And the health day is titled "Today"
    And the health day offers no "Next day"
    And the health card "Patterns" says "Not enough days"
    And the health card "What agents see" says "holds health"
    And the page has no axe breaches in light or dark

  Scenario Outline: The health page draws <columns> columns for span <span>
    When I open the health page with span "<span>"
    Then the health grid draws <columns> columns

    Examples:
      | span | columns |
      | 14   | 14      |
      | 90   | 90      |
      | 7    | 30      |

  Scenario: The health page flags a short night, low HRV, a raised resting heart rate and a late commit
    Given the health days:
      | day | asleep | hrv | resting | steps | zone | bed   | woke  |
      | 1   | 300    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 2   | 420    | 40  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 3   | 420    | 50  | 60      | 8421  | 22   | 23:00 | 06:00 |
      | 4   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 5   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 6   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 7   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 8   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 9   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 10  | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
    And the commits:
      | day | at    |
      | 1   | 22:30 |
    When I open the health page
    Then the health grid flags row 0 only on the day "1" days ago
    And the health grid flags row 1 only on the day "2" days ago
    And the health grid flags row 2 only on the day "3" days ago
    And the health grid flags row 6 only on the day "1" days ago
    And the health pattern reads "averaged 55.8 bpm over the last week, against 55 bpm"

  Scenario: The health page flags each day past the line its hint names, and none short of it
    Given the health days:
      | day | asleep | hrv | resting | steps | zone | bed   | woke  |
      | 1   | 359    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 2   | 360    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 3   | 420    | 40  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 4   | 420    | 44  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 5   | 420    | 50  | 60      | 8421  | 22   | 23:00 | 06:00 |
      | 6   | 420    | 50  | 57      | 8421  | 22   | 23:00 | 06:00 |
      | 7   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 8   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 9   | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
      | 10  | 420    | 50  | 55      | 8421  | 22   | 23:00 | 06:00 |
    And the commits:
      | day | at    |
      | 7   | 22:00 |
      | 8   | 21:59 |
    And an MCP client connected with the scopes "health"
    When I open the health page
    Then the health grid flags row 0 only on the day "1" days ago
    And the health grid flags row 1 only on the day "3" days ago
    And the health grid flags row 2 only on the day "5" days ago
    And the health grid flags row 6 only on the day "7" days ago
    And the health grid draws 30 columns
    And the health hint under the bar reads "Each column is one day. Pink marks under 6 hours asleep, HRV 5 below or resting heart rate 3 above your 30-day average, or a commit from 22:00 on."
    And the health patterns card hint reads "Averages over these days, not advice. Agents with health access get the same numbers for the same days."
    And the resting heart rate averages on the patterns card match read_health_days from 29 days ago

  Scenario: A day's detail shows its health, workouts and work against the 30 day baseline
    Given the health days:
      | day | asleep | hrv  | resting | steps | zone | bed   | woke  |
      | 4   | 300    | 48.4 | 54      | 8421  | 22   | 23:00 | 04:00 |
    And the workouts:
      | day | at    | kind    | minutes | distance | heart | kcal | device        |
      | 4   | 07:00 | RUNNING | 30      | 5000     | 150   | 330  | Pixel Watch 3 |
    And the commits:
      | day | at    |
      | 4   | 22:15 |
    And a task done on the health day "4" at "15:00"
    When I open the health page with span "14" on the day 4 days ago
    Then the health day is titled "4 days ago"
    And the health rows under "Body" read:
      | Asleep 23:00 → 04:005h 00m           |
      | HRV · 30-day 4848 ms                 |
      | Resting heart rate · 30-day 5454 bpm |
      | Steps · zone minutes8,421 · 22       |
    And the health value "5h 00m" is marked low
    And the health workout reads "Running · 5 km30m · avg 150 bpm · 330 kcal · Pixel Watch 307:00"
    And the health rows under "Work" read:
      | Focused time0m       |
      | Commits1             |
      | Commits after 22:001 |
      | Tasks done1          |
    And I see "This day in activity"
    And the health day links the days 5 and 3 days ago with span 14
    And the health grid marks the day 4 days ago
    And the page has no axe breaches in light or dark

  Scenario: The health page stops at the first day of the span
    When I open the health page with span "14" on the day 13 days ago
    Then the health day offers no "Previous day"

  Scenario: The health page opens on today when the day sits outside the span
    When I open the health page with span "14" on the day 20 days ago
    Then the health day is titled "Today"

  Scenario: The agents card lists the clients and tokens that hold health
    Given the MCP client "Claude" holding "read health"
    And the MCP client "Reader" holding "read"
    And the MCP client "Gone" holding "read health, revoked"
    And the MCP client "no name" holding "read health"
    And the API token "Terminal" holding "read health"
    And the API token "Script" holding "read"
    When I open the health page
    Then the health card "What agents see" lists:
      | claude.ai | MCP client |
      | Claude    | MCP client |
      | Terminal  | API token  |
