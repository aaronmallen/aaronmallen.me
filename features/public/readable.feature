Feature: Public screens
  Every public screen passes axe in light and dark, lets the Tab key reach every control in order behind a ring,
  and reads on a phone and a desk with no overflow, no text under 12px and no font preloaded but never drawn.

  Background:
    Given the public screens hold their usual records

  Scenario Outline: The <screen> screen is accessible and readable
    Given my window is 1280 by 800
    When I visit "<path>"
    Then the page has no axe breaches in light or dark
    And the Tab key reaches every control on the page in order, each behind a ring
    And the page reads well on the window, preloading only fonts it draws
    Given my window is 390 by 844
    When I visit "<path>"
    Then the page reads well on the window, preloading only fonts it draws

    Examples:
      | screen         | path                                                  |
      | about          | /about                                                |
      | board          | /projects/sai?view=board                              |
      | board list     | /projects/sai?view=list                               |
      | board filtered | /projects/sai?view=board&q=label:palette+author:me    |
      | contact        | /contact                                              |
      | contact sent   | /contact?sent=1                                       |
      | home           | /                                                     |
      | not found      | /writing/nothing-here                                 |
      | post           | /writing/hello                                        |
      | privacy        | /privacy                                              |
      | projects       | /projects                                             |
      | search         | /search                                               |
      | search nothing | /search?q=kafka                                       |
      | search results | /search?q=palette                                     |
      | tag            | /writing/tags/ruby                                    |
      | task           | /projects/sai/tasks/1                                 |
      | writing        | /writing                                              |

  Scenario: The contact screen with its fields refused is accessible and readable
    Given my window is 1280 by 800
    When I visit "/contact"
    And I click the button "Send message"
    Then the page has "#cf-email-error"
    And the page has no axe breaches in light or dark
    And the Tab key reaches every control on the page in order, each behind a ring
    And the page reads well on the window, preloading only fonts it draws
    Given my window is 390 by 844
    Then the page reads well on the window, preloading only fonts it draws

  @slow @timeout:90_000
  Scenario: The failed search screen is accessible and readable
    Given another session holds a lock on the posts table
    And my window is 1280 by 800
    When I visit "/search?q=palette"
    Then the page has ".sq-n.err"
    When the lock on the posts table goes
    And the page has no axe breaches in light or dark
    And the Tab key reaches every control on the page in order, each behind a ring
    And the page reads well on the window, preloading only fonts it draws
    Given my window is 390 by 844
    Then the page reads well on the window, preloading only fonts it draws
