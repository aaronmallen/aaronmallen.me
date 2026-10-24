Feature: Task comments in the admin
  The task page lists a task's comments oldest first, and adds, edits and deletes the owner's own comments.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title             |
      | Ship the comments |
      | Other             |

  Scenario: The task page lists the comments oldest first, rendered and made safe
    Given the task comments:
      | task              | body                                                            | at          | author  | url |
      | Ship the comments | Second                                                          | today 09:00 |         |     |
      | Ship the comments | Third                                                           | today 10:00 |         |     |
      | Ship the comments | First                                                           | today 08:00 |         |     |
      | Ship the comments | say **why** <script>alert(1)</script><a href="javascript:alert(1)">x</a> | today 11:00 | | |
      | Ship the comments | ![shot](https://example.com/shot.png)                           | today 12:00 | octocat | https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-5 |
      | Other             | Elsewhere                                                       | today 08:00 |         |     |
    When I visit "/admin/tasks/{task:Ship the comments}?filter=next"
    Then the page part ".task-comments > .f" reads "Comments"
    And the page parts ".task-comments .comment-body" read "First | Second | Third | say why x | shot"
    And the page has ".comment-body strong"
    And the page has no ".comment-body script"
    And the page has no ".comment-body a[href^='javascript']"
    And the page part "[data-task-comment='3'] .comment-author" reads "Aaron Allen"
    And the page has "[data-task-comment='3'] time[datetime^='{day:today}T08:00:00']"
    And the page has "form[action='/admin/tasks/1/comments/3'] textarea[name='comment[body]']"
    And the page has "[data-task-comment='3'] [data-markdown-editor] textarea#task-1-comment-3-body"
    And the page has "form[action='/admin/tasks/1/comments/3/delete'][data-confirm]"
    And the page part "[data-task-comment='5'] .comment-author" reads "octocat"
    And the page has "[data-task-comment='5'] time[datetime^='{day:today}T12:00:00']"
    And the page part "[data-task-comment='5'] a.task-source" has "href" set to "https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-5"
    And the page part "[data-task-comment='5'] .comment-body a" has "href" set to "https://example.com/shot.png"
    And the page has no "[data-task-comment='5'] img"
    And the page has no "[data-task-comment='5'] form"
    And the page has no "[data-task-comment='5'] details"
    And the page has no ".comment-edited"
    And the page has no "[data-task-comment='6']"
    And the page has no axe breaches in light or dark

  Scenario: The comment box carries the editor and an add button that works with no script
    Given the admin scripts do not load
    When I visit "/admin/tasks/{task:Ship the comments}?filter=next"
    Then the page has no ".task-comments .comment"
    And the page has ".stack-form [data-markdown-editor] [role='toolbar']"
    And the page has ".stack-form [data-markdown-editor] textarea[name='comment[body]']#task-1-comment-body"
    And the page has ".stack-form [data-markdown-editor] [data-editor-preview='/admin/markdown/preview/tasks']"
    And the page part ".stack-form [data-markdown-editor]" has "style" set to "--edit-height: 120px"
    And the page part "form[data-comment-add] button[type='submit']:not([hidden])" holds "Add comment"

  Scenario: Adding a comment saves it trimmed and comes back to where it was added
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments" with:
      | filter        | next                 |
      | comment[body] | "  Looked into it  " |
    Then the admin answer goes to a page starting "/admin/tasks?filter=next"
    And the database reads "1, Looked into it, " for:
      """
      SELECT task_id, body, coalesce(remote_id, '') FROM task_comments
      """
    When I follow the admin answer
    Then the toast says "Comment added"
    When I visit "/admin/tasks/{task:Ship the comments}?filter=next"
    Then the page part ".comment-body" reads "Looked into it"
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments" with:
      | filter        | today |
      | origin        | today |
      | comment[body] | Hello |
    Then the admin answer goes to "/admin"
    When I send the admin form "/admin/tasks/999999/comments" with:
      | filter        | next  |
      | comment[body] | Hello |
    Then the server answers 404

  Scenario: Adding an empty comment says why beside the field and keeps nothing
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments" with:
      | filter | next |
    Then the server answers 422
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments" with:
      | filter        | next  |
      | comment[body] | "   " |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-comment-body-error" reads "Write the comment first."
    And the page part "#task-1-comment-body" has "aria-describedby" set to "task-1-comment-body-error"
    And the page has "[data-task-read='1']"
    And the database holds 0 task_comments rows

  Scenario: Editing a comment saves the new body and flags it edited
    Given the task comments:
      | task              | body      | at            |
      | Ship the comments | Before    | today - 1     |
      | Other             | Elsewhere | today - 1     |
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1" with:
      | filter        | next  |
      | comment[body] | After |
    And I follow the admin answer
    Then the toast says "Comment saved"
    When I visit "/admin/tasks/{task:Ship the comments}?filter=next"
    Then the page part "[data-task-comment='1'] .comment-edited" reads "edited"
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/2" with:
      | filter        | next    |
      | comment[body] | Changed |
    Then the server answers 404
    And the database reads "After / Elsewhere" for:
      """
      SELECT body FROM task_comments ORDER BY id
      """

  Scenario: Editing a comment to nothing opens that comment's form with the error
    Given the task comments:
      | task              | body   |
      | Ship the comments | Before |
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1" with:
      | filter        | next |
      | comment[body] | " "  |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-comment-1-body-error" reads "Write the comment first."
    And the page has "[data-task-comment='1'] details.comment-edit[open]"
    And the page has no "#task-1-comment-body-error"
    And the database reads "Before" for:
      """
      SELECT body FROM task_comments
      """

  Scenario: Deleting a comment removes it and refuses one that is gone
    Given the task comments:
      | task              | body |
      | Ship the comments | Gone |
      | Ship the comments | Kept |
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1/delete" with:
      | filter | next |
    And I follow the admin answer
    Then the toast says "Comment deleted"
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1/delete" with:
      | filter | next |
    Then the server answers 404
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/nope/delete" with:
      | filter | next |
    Then the server answers 404
    And the database reads "Kept" for:
      """
      SELECT body FROM task_comments
      """

  Scenario: The admin leaves a synced comment alone
    Given the task comments:
      | task              | body        | author  | url                                                                  |
      | Ship the comments | From GitHub | octocat | https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-9 |
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1" with:
      | filter        | next         |
      | comment[body] | Changed here |
    Then the server answers 404
    When I send the admin form "/admin/tasks/{task:Ship the comments}/comments/1/delete" with:
      | filter | next |
    Then the server answers 404
    And the database reads "From GitHub" for:
      """
      SELECT body FROM task_comments
      """

  Scenario: Deleting a task removes its comments
    Given the task comments:
      | task              | body  |
      | Ship the comments | Hello |
    When I send the admin form "/admin/tasks/{task:Ship the comments}/delete" with:
      | filter | next |
    Then the database holds 0 task_comments rows
