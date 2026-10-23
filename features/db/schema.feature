Feature: Schema rules
  The schema keeps records whole on its own: links go when their record goes, and a shared file sits either
  under its own code or in a group.

  Scenario: Deleting a record of any kind drops its links
    Then the database answers "" for:
      """
      select string_agg(kind::text, ', ')
      from unnest(enum_range(null::record_kind)) as kind
      where not exists (
        select 1 from pg_trigger
        where not tgisinternal
          and pg_get_triggerdef(oid) like
            '%AFTER DELETE ON public.' || regexp_replace(kind::text, 'y$', 'ie') || 's %record_links_drop_record(''' || kind || ''')%'
      )
      """

  Scenario: A shared file cannot carry both a code and a group
    Given the database runs:
      """
      insert into short_codes (code) values ('the-deck'), ('cat-file');
      insert into share_groups (short_code_id) values (1);
      """
    Then the database refuses, breaking a check constraint:
      """
      insert into share_group_files (key, filename, content_type, byte_size, short_code_id, share_group_id)
      values (md5('a'), 'a.txt', 'text/plain', 2, 2, 1)
      """

  Scenario: A shared file must carry a code or a group
    Then the database refuses, breaking a check constraint:
      """
      insert into share_group_files (key, filename, content_type, byte_size) values (md5('a'), 'a.txt', 'text/plain', 2)
      """

  Scenario: A group's files stay out of the single shares
    Given the database runs:
      """
      insert into short_codes (code) values ('the-deck');
      insert into share_groups (short_code_id) values (1);
      insert into share_group_files (key, filename, content_type, byte_size, share_group_id)
      values (md5('a'), 'a.txt', 'text/plain', 2, 1);
      """
    And I am signed in to the admin
    When I visit "/admin/files"
    Then I see "0 files shared on"
    And the page has no axe breaches in light or dark
