Feature: The analytics chart in the browser
  The chart shows a day's figures when the owner hovers its bar, and the range
  control loads a longer range.

  Background:
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-1 | 30    | 20       | 600          |
      | today   | 10    | 5        | 300          |
    And I am signed in to the admin
    And I visit "/admin/analytics?range=7" in the admin

  Scenario: The analytics chart shows a day's figures only while its bar is hovered
    Then the screen holds no ".chart-tip:visible"
    When I hover over the analytics bar 6
    Then the screen parts ".chart-tip:visible" read:
      | {today-1 short} · 30 views · 20 visitors |

  Scenario: The analytics chart loads the range the owner picks
    When I pick the range "30d"
    Then I am on "/admin/analytics?range=30"
    And the screen holds 30 of ".chart-bar"
