Feature: Admin tag manager removes tags
  Removing a tag asks first, naming the tag and what loses it, then takes it off everything that carried it. A
  task rule's only tag stays, and the toast names the rules that hold it.

  Background:
    Given I am signed in to the admin

  Scenario: Removing a tag nothing carries takes it away and says so
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete"
    Then the tag manager shows "[data-toast]" reading "Tag removed"
    And the database answers "0" for:
      """
      select count(*) from tags
      """

  Scenario: The remove button asks first, naming the tag and warning nothing else loses it
    Given the tag manager holds the public tags "ruby"
    When I visit "/admin/settings/tagging"
    Then the tag manager's "form[action$='/delete']" has the data-confirm "Remove ruby? You can't undo it."

  Scenario: The remove button stays on while a record carries the tag, and counts each kind that loses it
    Given these records carry tags for the tag manager:
      | kind    | title    | tags |
      | post    | One      | ruby |
      | post    | Two      | ruby |
      | post    | Three    | ruby |
      | post    | Four     | ruby |
      | project | ruby-gem | ruby |
    When I visit "/admin/settings/tagging"
    Then the tag manager's "form[action$='/delete'] button" is enabled
    And the tag manager's "form[action$='/delete']" has no title
    And the tag manager's "form[action$='/delete']" has the data-confirm "Remove ruby? 4 posts and 1 project lose it."

  Scenario: The remove button counts one record that loses the tag
    Given these records carry tags for the tag manager:
      | kind    | title    | tags |
      | project | ruby-gem | ruby |
    When I visit "/admin/settings/tagging"
    Then the tag manager's "form[action$='/delete']" has the data-confirm "Remove ruby? 1 project loses it."

  Scenario: The remove button lists three kinds of private record that lose the tag
    Given these records carry tags for the tag manager:
      | kind          | title  | tags   |
      | journal entry | Swept  | chores |
      | task          | Sweep  | chores |
      | task          | Mop    | chores |
      | decision      | Broom? | chores |
    When I visit "/admin/settings/tagging?scope=private"
    Then the tag manager's "form[action$='/delete']" has the data-confirm "Remove chores? 1 journal entry, 2 tasks and 1 decision lose it."

  Scenario: Removing a tag two records carry takes it off them and says so
    Given these records carry tags for the tag manager:
      | kind | title | tags |
      | post | One   | ruby |
      | post | Two   | ruby |
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete"
    Then the tag manager shows "[data-toast]" reading "Tag removed"
    And the database answers "0, 0" for:
      """
      select (select count(*) from tags) as a, (select count(*) from post_tags) as b
      """

  Scenario: Removing a public tag takes it off every public record and leaves the other tags
    Given these records carry tags for the tag manager:
      | kind    | title    | tags        |
      | post    | On ruby  | ruby, rails |
      | project | ruby-gem | ruby        |
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete"
    Then the database answers "rails, 0" for:
      """
      select (select string_agg(t.name, ',') from post_tags pt join tags t on t.id = pt.tag_id) as a,
              (select count(*) from project_tags) as b
      """
    And the database answers "rails" for:
      """
      select string_agg(name, ',') from tags
      """

  Scenario: Removing a private tag takes it off every private record and message
    Given these records carry tags for the tag manager:
      | kind          | title  | tags   |
      | journal entry | Swept  | chores |
      | task          | Sweep  | chores |
      | decision      | Broom? | chores |
      | message       | Hi     | chores |
    When I post to the tag manager at "/admin/tags/{private:chores}/delete" with:
      | scope | private |
    Then the tag manager lands on "/admin/settings/tagging?scope=private#tags"
    And the database answers "0, 0, 0, 0, 0" for:
      """
      select (select count(*) from tags) as a, (select count(*) from journal_entry_tags) as b,
              (select count(*) from task_tags) as c, (select count(*) from decision_tags) as d,
              (select count(*) from mail_thread_tags) as e
      """

  Scenario: Removing a tag leaves a published post as it was updated
    Given these records carry tags for the tag manager:
      | kind           | title   | tags |
      | published post | On ruby | ruby |
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete"
    Then the database answers "true" for:
      """
      select updated_at < now() - interval '1 hour' from posts
      """

  Scenario: Removing a private tag from the private tab takes it away
    Given the tag manager holds the private tags "chores"
    When I post to the tag manager at "/admin/tags/{private:chores}/delete" with:
      | scope | private |
    Then the database answers "0" for:
      """
      select count(*) from tags
      """

  Scenario: Removing answers 404 for a tag from the other scope
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete" with:
      | scope | private |
    Then the tag manager answers 404

  Scenario: Removing a post's tag and a task rule's only tag takes the first and keeps the second, as the note says
    Given these records carry tags for the tag manager:
      | kind           | title   | tags |
      | published post | On ruby | ruby |
    And the tag manager has a task rule "rails/*" tagged "rules"
    When I post to the tag manager at "/admin/tags/{public:ruby}/delete"
    And I post to the tag manager at "/admin/tags/{private:rules}/delete" with:
      | scope | private |
    And I visit "/admin/settings/tagging"
    Then the database answers "0, rules" for:
      """
      select (select count(*) from post_tags) as a, (select string_agg(name, ',') from tags) as b
      """
    And the tag manager shows ".tag-panel-intro .hint" reading exactly "Removing a tag takes it off everything that carries it. A task rule's only tag can't be removed."

  Scenario: Removing the only tag on task rules keeps it on each rule and names the rules
    Given the tag manager has a task rule "rails/*" tagged "ruby"
    And the tag manager has a task rule "aaronmallen/*" tagged "ruby"
    When I post to the tag manager at "/admin/tags/{private:ruby}/delete" with:
      | scope | private |
    Then the tag manager lands on "/admin/settings/tagging?scope=private#tags"
    And the tag manager shows "[data-toast]" reading "only tag on the rules aaronmallen/*, rails/*"
    And the database answers "aaronmallen/* ruby | rails/* ruby" for:
      """
      select string_agg(r.pattern || ' ' || t.name, ' | ' order by r.pattern)
      from task_rules r join task_rule_tags rt on rt.task_rule_id = r.id join tags t on t.id = rt.tag_id
      """

  Scenario: Removing a tag a rule holds beside another takes it away
    Given the tag manager has a task rule "hanami/*" tagged "hanami, projects"
    When I post to the tag manager at "/admin/tags/{private:hanami}/delete" with:
      | scope | private |
    Then the database answers "projects" for:
      """
      select string_agg(t.name, ',') from task_rule_tags rt join tags t on t.id = rt.tag_id
      """
    And the database answers "0" for:
      """
      select count(*) from tags where name = 'hanami'
      """

  Scenario: Removing a rule's only tag works once the rules are gone
    Given the tag manager has a task rule "rails/*" tagged "ruby"
    And the tag manager has a task rule "aaronmallen/*" tagged "ruby"
    When I post to the tag manager at "/admin/tasks/rules/1/delete"
    And I post to the tag manager at "/admin/tasks/rules/2/delete"
    And I post to the tag manager at "/admin/tags/{private:ruby}/delete" with:
      | scope | private |
    Then the database answers "0" for:
      """
      select count(*) from tags
      """
