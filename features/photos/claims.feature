Feature: Photo claims
  A record claims each photo its Markdown points to, so the sweep keeps it, and it takes its photos with it when it
  goes.

  Background:
    Given the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" uploaded 2 days ago
    And the photo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg" uploaded 2 days ago
    And an MCP client connected with the scopes "read suggest write publish delete"

  Scenario: A post claims the photos its body points to, by path, sized path or full URL
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/1280/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](http://127.0.0.1/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)\n\n![Gone](/media/ffffffffffffffffffffffffffffffff.png)"}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When the photo sweep runs
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A post drops the claim on a photo taken out of its body and keeps the photo
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the post claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    And the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A post claims the photo in its Open Graph image field
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "text only", "og_image_url": "http://127.0.0.1/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A post claims the photo a social card write puts in the Open Graph image field
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "text only"}
      """
    And I call the MCP tool "write_post_seo" with:
      """
      {"id": 1, "og_image_url": "http://127.0.0.1/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A post claims a photo an accepted suggestion puts in its body
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "a cat sat here"}
      """
    And I call the MCP tool "suggest_edits" with:
      """
      {"target": "post", "id": 1, "edits": [{"original": "a cat", "replacement": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg) a cat", "reason": "show it"}]}
      """
    And I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A published post claims the photo its edit note points to and moves the claim when the note changes
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "one"}
      """
    And I call the MCP tool "publish_post" with:
      """
      {"id": 1}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "two", "edit_note": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "og_title": "On the card"}
      """
    Then the post claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "update_post_edit_note" with:
      """
      {"id": 1, "edit_id": 1, "note": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the post claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When the photo sweep runs
    Then the photos left are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A deleted post takes its photos from the table and the store
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "delete_post" with:
      """
      {"id": 1}
      """
    Then the photos left are ""
    And the photo store holds ""
    And no photo is claimed

  Scenario: A deleted post keeps a photo a journal entry also claims
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    And I call the MCP tool "create_journal_entry" with:
      """
      {"body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    And I call the MCP tool "delete_post" with:
      """
      {"id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    And the photo store holds "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A deleted post leaves a photo it no longer points to for the sweep
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "delete_post" with:
      """
      {"id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And the photo store holds "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A journal entry claims its photos, drops one taken out and deletes its photos with it
    When I call the MCP tool "create_journal_entry" with:
      """
      {"body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the journal_entry claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "update_journal_entry" with:
      """
      {"id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the journal_entry claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "delete_journal_entry" with:
      """
      {"id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And the photo store holds "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A review note claims its photos and drops one taken out
    When I call the MCP tool "save_review_note" with:
      """
      {"period": "week", "day": "2026-09-20", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the review_note claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "save_review_note" with:
      """
      {"period": "week", "day": "2026-09-20", "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the review_note claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A task claims the photos its note points to and drops one taken out
    When I call the MCP tool "capture_task" with:
      """
      {"title": "Fix the gutter", "note": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    Then the task claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "save_task" with:
      """
      {"id": 1, "note": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the task claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A deleted task takes its photos and its comments' photos with it
    When I call the MCP tool "capture_task" with:
      """
      {"title": "Fix the gutter", "note": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    And I call the MCP tool "add_task_comment" with:
      """
      {"id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "delete_task" with:
      """
      {"id": 1}
      """
    Then the photos left are ""
    And no photo is claimed

  Scenario: A task comment claims its photos, drops one taken out and deletes its photos with it
    When I call the MCP tool "capture_task" with:
      """
      {"title": "Fix the gutter"}
      """
    And I call the MCP tool "add_task_comment" with:
      """
      {"id": 1, "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the task_comment claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "edit_task_comment" with:
      """
      {"id": 1, "comment_id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the task_comment claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "delete_task_comment" with:
      """
      {"id": 1, "comment_id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And the photo store holds "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A decision claims the photos its problem points to and keeps them through the sweep
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    Then the decision claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "edit_decision" with:
      """
      {"id": 1, "problem": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When the photo sweep runs
    Then the photos left are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A dropped decision claims the photo its drop reason and its edit note point to
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "text only"}
      """
    And I call the MCP tool "drop_decision" with:
      """
      {"id": 1, "reason": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    Then the decision claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "edit_decision" with:
      """
      {"id": 1, "problem": "still text", "note": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A decision claims the photo its resolve reason points to
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    And I call the MCP tool "add_decision_option" with:
      """
      {"id": 1, "title": "Fly"}
      """
    And I call the MCP tool "resolve_decision" with:
      """
      {"id": 1, "option_id": 1, "reason": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A decision claims the photo its reopen reason points to
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    And I call the MCP tool "drop_decision" with:
      """
      {"id": 1, "reason": "No need"}
      """
    And I call the MCP tool "reopen_decision" with:
      """
      {"id": 1, "reason": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A decision option claims its photos, drops one taken out and deletes its photos with it
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "text only"}
      """
    And I call the MCP tool "add_decision_option" with:
      """
      {"id": 1, "title": "Good Job", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision_option claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "edit_decision_option" with:
      """
      {"id": 1, "option_id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision_option claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "delete_decision_option" with:
      """
      {"id": 1, "option_id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And no photo is claimed

  Scenario: A decision option's edit note claims its photo for the decision
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "text only"}
      """
    And I call the MCP tool "add_decision_option" with:
      """
      {"id": 1, "title": "Good Job", "body": "first"}
      """
    And I call the MCP tool "drop_decision" with:
      """
      {"id": 1, "reason": "No need"}
      """
    And I call the MCP tool "edit_decision_option" with:
      """
      {"id": 1, "option_id": 1, "body": "text only", "note": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"

  Scenario: A decision comment claims its photos, drops one taken out and deletes its photos with it
    When I call the MCP tool "open_decision" with:
      """
      {"title": "Pick a host", "problem": "text only"}
      """
    And I call the MCP tool "add_decision_comment" with:
      """
      {"id": 1, "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision_comment claims of photos are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "edit_decision_comment" with:
      """
      {"id": 1, "comment_id": 1, "body": "![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    Then the decision_comment claims of photos are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg"
    When I call the MCP tool "delete_decision_comment" with:
      """
      {"id": 1, "comment_id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And the photo store holds "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"

  Scenario: A deleted post keeps a photo whose store delete fails
    Given the photo store turns away the delete of "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)\n\n![Another](/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg)"}
      """
    And I call the MCP tool "delete_post" with:
      """
      {"id": 1}
      """
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    And no photo is claimed
