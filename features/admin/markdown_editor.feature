Feature: The Markdown editor in the admin
  Each Markdown editor on a page switches, inserts snippets and previews on its own, through its own renderer.

  Background:
    Given I am signed in to the admin
    And a decision "Pick a queue" with the problem "Jobs pile up"
    And I visit "/admin/decisions/1"
    And I click the element ".decision-add summary"

  Scenario: Picking Preview switches one editor and leaves the other on Write
    Given "textarea[name='option[body]']" is visible
    When I click the element "[data-markdown-editor]:has(textarea[name='option[body]']) .seg-option:has-text('Preview')"
    Then "textarea[name='option[body]']" is hidden
    And "textarea[name='comment[body]']" is visible

  Scenario: Each editor takes its own height
    Then every one of "textarea[name='option[body]']" is at least 160 pixels tall
    And every one of "textarea[name='comment[body]']" is at least 120 pixels tall

  Scenario: A snippet goes in its own editor only
    When I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) button[aria-label='Bold']"
    Then the page field "textarea[name='comment[body]']" holds "**bold**"
    And the page field "textarea[name='option[body]']" holds ""

  Scenario: The task preview keeps the HTML the task renderer allows
    When I fill the field "textarea[name='comment[body]']" with:
      """
      <details><summary>More</summary>hidden</details>
      """
    And I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "[data-markdown-editor]:has(textarea[name='comment[body]']) .preview details summary" reads "More"

  Scenario: The task preview strips a raw script
    When I fill the field "textarea[name='comment[body]']" with:
      """
      <script>window.ran = true</script>

      safe
      """
    And I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "[data-markdown-editor]:has(textarea[name='comment[body]']) .preview p" reads "safe"
    And the page has no "[data-markdown-editor]:has(textarea[name='comment[body]']) .preview script"
    And the window's "ran" is not set

  Scenario: The next switch to Preview shows the body as it stands
    When I fill the field "textarea[name='comment[body]']" with:
      """
      first
      """
    And I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "[data-markdown-editor]:has(textarea[name='comment[body]']) .preview p" reads "first"
    When I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Write')"
    And I fill the field "textarea[name='comment[body]']" with:
      """
      second
      """
    And I click the element "[data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "[data-markdown-editor]:has(textarea[name='comment[body]']) .preview p" reads "second"

  Scenario: The post preview drops the HTML through the post renderer
    When I visit "/admin/journal"
    And I fill the field "textarea[name='entry[body]']" with:
      """
      <details><summary>More</summary>hidden</details>
      """
    And I click the element "[data-markdown-editor]:has(textarea[name='entry[body]']) .seg-option:has-text('Preview')"
    Then the page has "[data-markdown-editor]:has(textarea[name='entry[body]']) .preview .post-body"
    And the page has no "[data-markdown-editor]:has(textarea[name='entry[body]']) .preview details"
