Feature: The wordmark
  The wordmark rests until hovered or focused, then cycles its slash through the public colors, unless the
  reader asks for reduced motion. The public header and the admin top bar share it.

  Scenario Outline: The wordmark in <place> starts pink, sits at the brand size and rests
    Given <signed in>
    When I visit "<path>"
    Then the "color" of ".wordmark-slash" is the color "var(--color-mk-pink-text)"
    And the "font-size" of "a.wordmark" is "18px"
    And the "custom" property "--cy" of "a.wordmark" is the list:
      | --color-mk-pink-text   |
      | --color-mk-orange-text |
      | --color-mk-sand-text   |
      | --color-mk-green-text  |
      | --color-mk-blue-text   |
      | --color-mk-violet-text |
    And ".wordmark-slash" is not animating

    Examples:
      | place           | signed in                     | path   |
      | the public header | I am not signed in          | /      |
      | the admin top bar | I am signed in to the admin | /admin |

  Scenario Outline: The wordmark in <place> cycles on hover and on focus, and rings in the accent on focus
    Given <signed in>
    When I visit "<path>"
    And I hover over "a.wordmark"
    Then ".wordmark-slash" is animating
    When I visit "<path>"
    And I focus "a.wordmark" from the keyboard
    Then ".wordmark-slash" is animating
    And the "outline-color" of "a.wordmark" is the color "var(--color-accent)"

    Examples:
      | place             | signed in                   | path   |
      | the public header | I am not signed in          | /      |
      | the admin top bar | I am signed in to the admin | /admin |

  Scenario Outline: The wordmark in <place> holds still with reduced motion on
    Given <signed in>
    And I prefer reduced motion
    When I visit "<path>"
    And I hover over "a.wordmark"
    Then ".wordmark-slash" is not animating

    Examples:
      | place             | signed in                   | path   |
      | the public header | I am not signed in          | /      |
      | the admin top bar | I am signed in to the admin | /admin |
