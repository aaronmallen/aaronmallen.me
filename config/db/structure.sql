--
-- PostgreSQL database dump
--



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: artifact_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.artifact_type AS ENUM (
    'plan',
    'spec',
    'research',
    'handoff',
    'notes',
    'review',
    'postmortem',
    'other'
);


--
-- Name: attention_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.attention_kind AS ENUM (
    'carried',
    'draft',
    'someday',
    'journal',
    'new_device',
    'broken_link',
    'lapsing'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.code_challenge_method AS ENUM (
    'S256'
);


--
-- Name: contributor_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contributor_kind AS ENUM (
    'owner',
    'agent'
);


--
-- Name: contributor_slug; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.contributor_slug AS text
	CONSTRAINT contributor_slug_check CHECK (((VALUE ~ '^[a-z0-9]+([.-][a-z0-9]+)*$'::text) AND (length(VALUE) <= 64)));


--
-- Name: country_code; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.country_code AS text
	CONSTRAINT country_code_check CHECK ((VALUE ~ '^[A-Z]{2}$'::text));


--
-- Name: decision_event_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.decision_event_kind AS ENUM (
    'opened',
    'option_added',
    'option_edited',
    'edited',
    'resolved',
    'dropped',
    'reopened'
);


--
-- Name: decision_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.decision_status AS ENUM (
    'open',
    'resolved',
    'dropped'
);


--
-- Name: device_class; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.device_class AS ENUM (
    'desktop',
    'mobile',
    'tablet',
    'in-app'
);


--
-- Name: email_address; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.email_address AS text
	CONSTRAINT email_address_check CHECK ((VALUE ~ '^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$'::text));


--
-- Name: hostname; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.hostname AS text
	CONSTRAINT hostname_check CHECK ((VALUE ~ '^[^\s/]+$'::text));


--
-- Name: http_path; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.http_path AS text
	CONSTRAINT http_path_check CHECK ((VALUE ~ '^/'::text));


--
-- Name: mail_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mail_category AS ENUM (
    'personal',
    'social',
    'promotions',
    'updates',
    'forums'
);


--
-- Name: mail_provider; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mail_provider AS ENUM (
    'contact_form',
    'gmail'
);


--
-- Name: mastodon_handle; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.mastodon_handle AS text
	CONSTRAINT mastodon_handle_check CHECK ((VALUE ~ '^@[^@\s]+@[^@\s]+$'::text));


--
-- Name: memory_event_op; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.memory_event_op AS ENUM (
    'create',
    'add',
    'edit',
    'remove',
    'revert',
    'scope',
    'describe'
);


--
-- Name: memory_fact_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.memory_fact_type AS ENUM (
    'preference',
    'convention',
    'gotcha',
    'context'
);


--
-- Name: memory_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.memory_scope AS ENUM (
    'global',
    'project',
    'task'
);


--
-- Name: message_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_status AS ENUM (
    'unread',
    'read',
    'spam'
);


--
-- Name: network; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.network AS ENUM (
    'bluesky',
    'mastodon',
    'linkedin'
);


--
-- Name: non_blank_text; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.non_blank_text AS text
	CONSTRAINT non_blank_text_check CHECK ((VALUE ~ '\S'::text));


--
-- Name: oauth_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oauth_scope AS ENUM (
    'read',
    'suggest',
    'write',
    'publish',
    'delete',
    'health',
    'mail',
    'agents'
);


--
-- Name: oauth_token_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oauth_token_type AS ENUM (
    'access',
    'refresh'
);


--
-- Name: partial_date; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.partial_date AS text
	CONSTRAINT partial_date_check CHECK ((VALUE ~ '^([0-9]{4}|-)-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'::text));


--
-- Name: performance_job_outcome; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.performance_job_outcome AS ENUM (
    'succeeded',
    'failed'
);


--
-- Name: performance_page_metric; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.performance_page_metric AS ENUM (
    'ttfb',
    'dom_content_loaded',
    'load',
    'lcp'
);


--
-- Name: photo_key; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.photo_key AS text
	CONSTRAINT photo_key_check CHECK ((VALUE ~ '^[0-9a-f]{32}\.(gif|jpg|png|webp)$'::text));


--
-- Name: photo_owner; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.photo_owner AS ENUM (
    'post',
    'journal_entry',
    'task',
    'task_comment',
    'decision_comment',
    'review_note',
    'social_post_part',
    'decision',
    'decision_option'
);


--
-- Name: post_follow_up; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.post_follow_up AS ENUM (
    'syndicate_post',
    'send_webmentions'
);


--
-- Name: post_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.post_status AS ENUM (
    'draft',
    'scheduled',
    'published'
);


--
-- Name: project_key; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.project_key AS text
	CONSTRAINT project_key_check CHECK ((VALUE ~ '^[A-Z][A-Z0-9]{1,5}$'::text));


--
-- Name: project_visibility; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.project_visibility AS ENUM (
    'public',
    'private'
);


--
-- Name: record_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.record_kind AS ENUM (
    'task',
    'post',
    'social_post',
    'journal_entry',
    'commit',
    'project',
    'work_entry',
    'decision',
    'pull_request',
    'mail_thread',
    'memory_file',
    'artifact'
);


--
-- Name: record_link_relation; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.record_link_relation AS ENUM (
    'related',
    'sourced_from'
);


--
-- Name: ref_source; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.ref_source AS text
	CONSTRAINT ref_source_check CHECK (((VALUE ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'::text) AND (length(VALUE) <= 32)));


--
-- Name: repo_name; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.repo_name AS text
	CONSTRAINT repo_name_check CHECK ((VALUE ~ '^[a-z0-9][a-z0-9-]*/[a-z0-9._-]+$'::text));


--
-- Name: repo_pattern; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.repo_pattern AS text
	CONSTRAINT repo_pattern_check CHECK ((VALUE ~ '^[a-z0-9][a-z0-9-]*/([a-z0-9._-]+|\*)$'::text));


--
-- Name: review_period; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.review_period AS ENUM (
    'week',
    'month'
);


--
-- Name: saved_view_screen; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.saved_view_screen AS ENUM (
    'activity',
    'journal',
    'posts',
    'tasks'
);


--
-- Name: scroll_depth; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.scroll_depth AS smallint
	CONSTRAINT scroll_depth_check CHECK ((VALUE = ANY (ARRAY[0, 25, 50, 75, 100])));


--
-- Name: short_code; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.short_code AS text
	CONSTRAINT short_code_check CHECK ((VALUE ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));


--
-- Name: sign_in_outcome; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sign_in_outcome AS ENUM (
    'signed_in',
    'denied',
    'provider_failed',
    'wrong_account',
    'unexpected'
);


--
-- Name: sign_in_provider; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sign_in_provider AS ENUM (
    'github',
    'google'
);


--
-- Name: social_post_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.social_post_status AS ENUM (
    'draft',
    'scheduled',
    'posted'
);


--
-- Name: suggestion_edit_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.suggestion_edit_status AS ENUM (
    'pending',
    'accepted',
    'rejected',
    'stale'
);


--
-- Name: sync_name; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_name AS ENUM (
    'analytics_rollup',
    'commits',
    'country_database',
    'projects',
    'issues',
    'linear_issues',
    'backups',
    'pull_requests',
    'health',
    'mail',
    'calendar',
    'contacts'
);


--
-- Name: sync_state_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_state_kind AS ENUM (
    'commits',
    'backfill',
    'failure',
    'pull_requests'
);


--
-- Name: tag_color; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tag_color AS ENUM (
    'mk-pink',
    'mk-green',
    'mk-blue',
    'mk-violet',
    'mk-sand',
    'mk-orange'
);


--
-- Name: tag_name; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.tag_name AS text
	CONSTRAINT tag_name_check CHECK ((VALUE ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));


--
-- Name: tag_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tag_scope AS ENUM (
    'public',
    'private'
);


--
-- Name: task_cadence; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_cadence AS ENUM (
    'days',
    'weeks',
    'month_day',
    'month_end',
    'month_weekday',
    'yearly'
);


--
-- Name: task_event_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_event_kind AS ENUM (
    'moved',
    'tagged',
    'untagged',
    'status_changed',
    'recurred'
);


--
-- Name: task_link_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_link_type AS ENUM (
    'blocks',
    'relates',
    'duplicates',
    'parent'
);


--
-- Name: task_list; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_list AS ENUM (
    'next',
    'someday',
    'external'
);


--
-- Name: task_source_provider; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_source_provider AS ENUM (
    'github',
    'linear'
);


--
-- Name: task_source_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_source_state AS ENUM (
    'open',
    'completed',
    'not_planned',
    'unassigned',
    'moved',
    'deleted',
    'started'
);


--
-- Name: task_stage; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_stage AS ENUM (
    'backlog',
    'ready'
);


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_status AS ENUM (
    'open',
    'in_progress',
    'done',
    'canceled'
);


--
-- Name: view_token; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.view_token AS text
	CONSTRAINT view_token_check CHECK ((VALUE ~ '^[0-9a-f]{32}$'::text));


--
-- Name: visitor_hash; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.visitor_hash AS text
	CONSTRAINT visitor_hash_check CHECK ((VALUE ~ '^[0-9a-f]{64}$'::text));


--
-- Name: webmention_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.webmention_status AS ENUM (
    'pending',
    'approved',
    'ignored',
    'spam'
);


--
-- Name: webmention_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.webmention_type AS ENUM (
    'reply',
    'like',
    'repost',
    'mention'
);


--
-- Name: artifact_versions_next_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.artifact_versions_next_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE artifacts SET version = version + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.artifact_id
    RETURNING version INTO NEW.number;

  RETURN NEW;
END
$$;


--
-- Name: attention_snoozes_drop_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.attention_snoozes_drop_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM attention_snoozes WHERE kind::text = ANY(TG_ARGV) AND record_id = OLD.id;

  RETURN OLD;
END;
$$;


--
-- Name: note_folders_refuse_loop(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.note_folders_refuse_loop() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    WITH RECURSIVE ancestors(id) AS (
      SELECT NEW.parent_id
      UNION
      SELECT note_folders.parent_id FROM note_folders JOIN ancestors ON note_folders.id = ancestors.id
    )
    SELECT 1 FROM ancestors WHERE id = NEW.id
  ) THEN
    RAISE EXCEPTION 'a folder cannot sit inside itself'
      USING ERRCODE = 'check_violation', CONSTRAINT = 'note_folders_parent_loop';
  END IF;

  RETURN NEW;
END
$$;


--
-- Name: notes_next_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notes_next_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.version := OLD.version + 1;

  RETURN NEW;
END
$$;


--
-- Name: notify_admin_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_admin_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  bookkeeping text[] := ARRAY['click_count', 'download_count', 'history_id', 'last_clicked_at', 'last_used_at', 'updated_at', 'view_count', 'zip_download_count', 'credentials', 'settings_synced_at', 'sync_token', 'synced_from'];
BEGIN
  IF TG_OP <> 'UPDATE' OR to_jsonb(OLD) - bookkeeping IS DISTINCT FROM to_jsonb(NEW) - bookkeeping THEN
    PERFORM pg_notify('admin_changes', TG_TABLE_NAME);
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: post_tags_record_removal(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_tags_record_removal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM posts WHERE id = OLD.post_id AND status = 'published') THEN
    INSERT INTO post_tag_removals (post_id, tag_id) VALUES (OLD.post_id, OLD.tag_id)
      ON CONFLICT (post_id, tag_id) DO UPDATE SET removed_at = EXCLUDED.removed_at;
  END IF;

  RETURN OLD;
END;
$$;


--
-- Name: posts_default_webmentions_enabled(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_default_webmentions_enabled() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.webmentions_enabled := coalesce(
    NEW.webmentions_enabled,
    (SELECT enable_on_new_posts FROM webmention_settings LIMIT 1),
    true
  );

  RETURN NEW;
END;
$$;


--
-- Name: posts_lock_published_slug(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_lock_published_slug() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.status = 'published' AND NEW.slug IS DISTINCT FROM OLD.slug THEN
    RAISE EXCEPTION 'the slug of a published post cannot change'
      USING ERRCODE = 'check_violation', CONSTRAINT = 'posts_published_slug_locked';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: posts_record_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_record_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO post_deletions (post_id) VALUES (OLD.id);

  RETURN OLD;
END;
$$;


--
-- Name: projects_default_key(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.projects_default_key() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  base text := coalesce(nullif(left(regexp_replace(upper(NEW.name), '[^A-Z]', '', 'g'), 3), ''), 'PRJ');
  marks text[] := regexp_split_to_array('23456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', '');
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('projects_default_key'));

  SELECT candidate INTO NEW.key
    FROM (
      SELECT base AS candidate, 0 AS place
      UNION ALL
      SELECT base || one.mark, one.place FROM unnest(marks) WITH ORDINALITY AS one(mark, place)
      UNION ALL
      SELECT base || one.mark || two.mark, 100 * one.place + two.place
        FROM unnest(marks) WITH ORDINALITY AS one(mark, place),
          unnest(marks) WITH ORDINALITY AS two(mark, place)
    ) candidates
    WHERE length(candidate) >= 2
      AND NOT EXISTS (
        SELECT 1 FROM projects
          WHERE lower(projects.key) = lower(candidate) AND projects.id IS DISTINCT FROM NEW.id
      )
    ORDER BY length(candidate), place
    LIMIT 1;

  RETURN NEW;
END
$$;


--
-- Name: record_links_drop_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_links_drop_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM record_links
  WHERE (left_kind = TG_ARGV[0]::record_kind AND left_id = OLD.id)
    OR (right_kind = TG_ARGV[0]::record_kind AND right_id = OLD.id);

  RETURN OLD;
END;
$$;


--
-- Name: record_links_find_records(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_links_find_records() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT record_links_record_exists(NEW.left_kind, NEW.left_id)
    OR NOT record_links_record_exists(NEW.right_kind, NEW.right_id) THEN
    RAISE EXCEPTION 'a record link names a record that does not exist'
      USING ERRCODE = 'foreign_key_violation', CONSTRAINT = 'record_links_record_missing';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: record_links_record_exists(public.record_kind, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_links_record_exists(kind public.record_kind, record_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  CASE kind
    WHEN 'task' THEN PERFORM 1 FROM tasks WHERE id = record_id FOR KEY SHARE;
    WHEN 'post' THEN PERFORM 1 FROM posts WHERE id = record_id FOR KEY SHARE;
    WHEN 'social_post' THEN PERFORM 1 FROM social_posts WHERE id = record_id FOR KEY SHARE;
    WHEN 'journal_entry' THEN PERFORM 1 FROM journal_entries WHERE id = record_id FOR KEY SHARE;
    WHEN 'commit' THEN PERFORM 1 FROM commits WHERE id = record_id FOR KEY SHARE;
    WHEN 'project' THEN PERFORM 1 FROM projects WHERE id = record_id FOR KEY SHARE;
    WHEN 'work_entry' THEN PERFORM 1 FROM work_entries WHERE id = record_id FOR KEY SHARE;
    WHEN 'decision' THEN PERFORM 1 FROM decisions WHERE id = record_id FOR KEY SHARE;
    WHEN 'pull_request' THEN PERFORM 1 FROM pull_requests WHERE id = record_id FOR KEY SHARE;
    WHEN 'mail_thread' THEN PERFORM 1 FROM mail_threads WHERE id = record_id FOR KEY SHARE;
    WHEN 'memory_file' THEN PERFORM 1 FROM memory_files WHERE id = record_id FOR KEY SHARE;
    WHEN 'artifact' THEN PERFORM 1 FROM artifacts WHERE id = record_id FOR KEY SHARE;
  END CASE;

  RETURN FOUND;
END;
$$;


--
-- Name: task_rules_last_target(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.task_rules_last_target() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  held integer[];
BEGIN
  IF TG_TABLE_NAME = 'tags' THEN
    held := ARRAY(SELECT task_rule_id FROM task_rule_tags WHERE tag_id = OLD.id);
  ELSE
    held := ARRAY(SELECT task_rule_id FROM task_rule_projects WHERE project_id = OLD.id);
  END IF;

  PERFORM 1 FROM task_rules WHERE id = ANY (held) FOR SHARE;

  IF EXISTS (
    SELECT 1 FROM unnest(held) AS rule(id)
      WHERE NOT EXISTS (
        SELECT 1 FROM task_rule_tags other
          WHERE other.task_rule_id = rule.id AND (TG_TABLE_NAME <> 'tags' OR other.tag_id <> OLD.id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM task_rule_projects other
          WHERE other.task_rule_id = rule.id AND (TG_TABLE_NAME <> 'projects' OR other.project_id <> OLD.id)
      )
  ) THEN
    RAISE EXCEPTION 'removing % % would leave a task rule with no tags or projects', TG_TABLE_NAME, OLD.id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'task_rules_last_target';
  END IF;

  RETURN OLD;
END;
$$;


--
-- Name: tasks_next_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_next_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('tasks_next_number'), coalesce(NEW.project_id, 0));

  INSERT INTO task_number_counters (project_id, last_number)
    VALUES (
      NEW.project_id,
      (SELECT coalesce(max(number), 0) + 1 FROM tasks WHERE project_id IS NOT DISTINCT FROM NEW.project_id)
    )
    ON CONFLICT (project_id) DO UPDATE
      SET last_number = greatest(task_number_counters.last_number + 1, EXCLUDED.last_number)
    RETURNING last_number INTO NEW.number;

  RETURN NEW;
END
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commits (
    id integer NOT NULL,
    sha text NOT NULL,
    repo text NOT NULL,
    branch text NOT NULL,
    message text NOT NULL,
    commit_date date NOT NULL,
    commit_time time without time zone NOT NULL,
    additions integer DEFAULT 0 NOT NULL,
    deletions integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE(split_part(message, '
'::text, 1), ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE(repo, ''::text) || ' '::text) || COALESCE(regexp_replace(message, '^[^\n]*\n?'::text, ''::text), ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT commits_additions_check CHECK ((additions >= 0)),
    CONSTRAINT commits_deletions_check CHECK ((deletions >= 0))
);


--
-- Name: decision_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_comments (
    id integer NOT NULL,
    decision_id integer NOT NULL,
    body public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: decision_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_events (
    id integer NOT NULL,
    decision_id integer NOT NULL,
    kind public.decision_event_kind NOT NULL,
    option_id integer,
    reason public.non_blank_text,
    note public.non_blank_text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT decision_events_kind_check CHECK (
CASE kind
    WHEN 'opened'::public.decision_event_kind THEN (num_nonnulls(option_id, reason, note) = 0)
    WHEN 'option_added'::public.decision_event_kind THEN ((option_id IS NOT NULL) AND (num_nonnulls(reason, note) = 0))
    WHEN 'option_edited'::public.decision_event_kind THEN ((option_id IS NOT NULL) AND (reason IS NULL))
    WHEN 'edited'::public.decision_event_kind THEN (num_nonnulls(option_id, reason) = 0)
    WHEN 'resolved'::public.decision_event_kind THEN ((option_id IS NOT NULL) AND (reason IS NOT NULL) AND (note IS NULL))
    WHEN 'dropped'::public.decision_event_kind THEN ((option_id IS NULL) AND (reason IS NOT NULL) AND (note IS NULL))
    WHEN 'reopened'::public.decision_event_kind THEN ((option_id IS NULL) AND (reason IS NOT NULL) AND (note IS NULL))
    ELSE false
END),
    CONSTRAINT decision_events_note_length_check CHECK ((char_length((note)::text) <= 500))
);


--
-- Name: decision_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_options (
    id integer NOT NULL,
    decision_id integer NOT NULL,
    title public.non_blank_text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decisions (
    id integer NOT NULL,
    title public.non_blank_text NOT NULL,
    problem public.non_blank_text NOT NULL,
    status public.decision_status DEFAULT 'open'::public.decision_status NOT NULL,
    resolved_option_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((title)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, COALESCE((problem)::text, ''::text)), 'B'::"char"))) STORED,
    CONSTRAINT decisions_choice_check CHECK (((status = 'resolved'::public.decision_status) = (resolved_option_id IS NOT NULL)))
);


--
-- Name: journal_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entries (
    id integer NOT NULL,
    entry_date date NOT NULL,
    entry_time time without time zone NOT NULL,
    body public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, COALESCE((body)::text, ''::text)), 'B'::"char")) STORED,
    body_html text NOT NULL,
    word_count integer GENERATED ALWAYS AS (regexp_count((body)::text, '\S+'::text)) STORED NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    status public.post_status DEFAULT 'draft'::public.post_status NOT NULL,
    published_at timestamp with time zone,
    body text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    webmentions_enabled boolean NOT NULL,
    webmention_targets text[] DEFAULT '{}'::text[] NOT NULL,
    syndication_enabled boolean DEFAULT false NOT NULL,
    syndication_body text DEFAULT ''::text NOT NULL,
    syndication_targets public.network[] DEFAULT '{}'::public.network[] NOT NULL,
    summary text DEFAULT ''::text NOT NULL,
    og_title text DEFAULT ''::text NOT NULL,
    og_image_url text DEFAULT ''::text NOT NULL,
    canonical_url text DEFAULT ''::text NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE(title, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE(summary, ''::text) || ' '::text) || COALESCE(body, ''::text))), 'B'::"char"))) STORED,
    unsent_webmention_targets text[] DEFAULT '{}'::text[] NOT NULL,
    body_html text NOT NULL,
    first_paragraph text,
    read_time integer NOT NULL,
    word_count integer NOT NULL,
    CONSTRAINT posts_published_at_check CHECK (((status = 'draft'::public.post_status) OR (published_at IS NOT NULL)))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id integer NOT NULL,
    name public.non_blank_text NOT NULL,
    tagline text,
    repo public.repo_name,
    url text,
    stars integer DEFAULT 0 NOT NULL,
    release text,
    started_on date,
    archived_on date,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    og_image_url text,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((name)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE(tagline, ''::text) || ' '::text) || COALESCE((repo)::text, ''::text))), 'B'::"char"))) STORED,
    visibility public.project_visibility NOT NULL,
    board_published boolean DEFAULT false NOT NULL,
    key public.project_key NOT NULL,
    CONSTRAINT projects_archived_order_check CHECK ((archived_on >= started_on)),
    CONSTRAINT projects_stars_check CHECK ((stars >= 0))
);


--
-- Name: pull_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pull_requests (
    id integer NOT NULL,
    repo text NOT NULL,
    number integer NOT NULL,
    title text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    url text NOT NULL,
    ready_at timestamp with time zone,
    merged_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, title), 'A'::"char") || setweight(to_tsvector('english'::regconfig, body), 'B'::"char"))) STORED,
    opened_at timestamp with time zone NOT NULL,
    CONSTRAINT pull_requests_merged_or_closed_check CHECK (((merged_at IS NULL) OR (closed_at IS NULL)))
);


--
-- Name: social_post_parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_post_parts (
    id integer NOT NULL,
    social_post_id integer NOT NULL,
    "position" integer NOT NULL,
    body public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, COALESCE((body)::text, ''::text)), 'B'::"char")) STORED,
    CONSTRAINT social_post_parts_position_check CHECK (("position" > 0))
);


--
-- Name: social_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_posts (
    id integer NOT NULL,
    post_id integer,
    targets public.network[] NOT NULL,
    status public.social_post_status DEFAULT 'draft'::public.social_post_status NOT NULL,
    posted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    connection_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    CONSTRAINT social_posts_posted_at_check CHECK (((status = 'draft'::public.social_post_status) OR (posted_at IS NOT NULL))),
    CONSTRAINT social_posts_targets_check CHECK ((cardinality(targets) > 0))
);


--
-- Name: sprints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sprints (
    id integer NOT NULL,
    sprint_date date NOT NULL,
    carried_in integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT sprints_carried_in_check CHECK ((carried_in >= 0))
);


--
-- Name: suggestions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suggestions (
    id integer NOT NULL,
    post_id integer,
    social_post_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT suggestions_target_check CHECK (((post_id IS NULL) <> (social_post_id IS NULL)))
);


--
-- Name: task_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_comments (
    id integer NOT NULL,
    task_id integer NOT NULL,
    body public.non_blank_text NOT NULL,
    provider public.task_source_provider,
    remote_id text,
    url text,
    author text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT task_comments_remote_check CHECK ((num_nonnulls(provider, remote_id, url) = ANY (ARRAY[0, 3])))
);


--
-- Name: task_contributors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_contributors (
    id integer NOT NULL,
    task_id integer NOT NULL,
    kind public.contributor_kind NOT NULL,
    agent public.contributor_slug,
    model public.contributor_slug,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT task_contributors_kind_check CHECK ((num_nonnulls(agent, model) =
CASE kind
    WHEN 'owner'::public.contributor_kind THEN 0
    ELSE 2
END))
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id integer NOT NULL,
    title public.non_blank_text NOT NULL,
    note text DEFAULT ''::text NOT NULL,
    list public.task_list,
    sprint_id integer,
    status public.task_status DEFAULT 'open'::public.task_status NOT NULL,
    "position" integer NOT NULL,
    carried_count integer DEFAULT 0 NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    worked_seconds integer DEFAULT 0 NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((title)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, COALESCE(note, ''::text)), 'B'::"char"))) STORED,
    stage public.task_stage DEFAULT 'backlog'::public.task_stage NOT NULL,
    project_id integer,
    number integer NOT NULL,
    series_id integer,
    CONSTRAINT tasks_carried_count_check CHECK ((carried_count >= 0)),
    CONSTRAINT tasks_completed_at_check CHECK (((status = ANY (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) = (completed_at IS NOT NULL))),
    CONSTRAINT tasks_list_or_sprint_check CHECK ((num_nonnulls(list, sprint_id) = 1)),
    CONSTRAINT tasks_number_check CHECK ((number > 0)),
    CONSTRAINT tasks_worked_seconds_check CHECK ((worked_seconds >= 0))
);


--
-- Name: webmentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webmentions (
    id integer NOT NULL,
    post_id integer NOT NULL,
    source_url public.non_blank_text NOT NULL,
    author_name text,
    author_url text,
    author_domain text GENERATED ALWAYS AS (lower("substring"(author_url, '^[^:]+://(?:[^@/]*@)?([^/:?#]+)'::text))) STORED,
    type public.webmention_type NOT NULL,
    status public.webmention_status DEFAULT 'pending'::public.webmention_status NOT NULL,
    excerpt text,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    spam_reason public.non_blank_text,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE(author_name, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE(excerpt, ''::text) || ' '::text) || COALESCE((source_url)::text, ''::text))), 'B'::"char"))) STORED,
    seen_at timestamp with time zone,
    snoozed_until timestamp with time zone,
    CONSTRAINT webmentions_source_url_check CHECK ((octet_length((source_url)::text) <= 2048)),
    CONSTRAINT webmentions_spam_reason_check CHECK (((status = 'spam'::public.webmention_status) OR (spam_reason IS NULL)))
);


--
-- Name: work_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_sessions (
    id integer NOT NULL,
    task_id integer NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT work_sessions_order_check CHECK ((ended_at >= started_at))
);


--
-- Name: workouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workouts (
    id integer NOT NULL,
    google_id text NOT NULL,
    kind text NOT NULL,
    started_at timestamp with time zone NOT NULL,
    minutes integer NOT NULL,
    distance_meters double precision,
    average_heart_rate integer,
    zone_minutes integer,
    kcal integer,
    device text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: activities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.activities AS
 SELECT 'commit'::text AS type,
    commits.id AS source_id,
    commits.commit_date AS occurred_on,
    commits.commit_time AS occurred_at,
    commits.message AS name,
    NULL::text AS link,
    commits.repo,
    commits.sha,
    commits.additions,
    commits.deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.commits
UNION ALL
 SELECT 'post'::text AS type,
    posts.id AS source_id,
    ((posts.published_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((posts.published_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    posts.title AS name,
    ('/writing/'::text || posts.slug) AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    (posts.status)::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.posts
  WHERE (posts.status = 'published'::public.post_status)
UNION ALL
 SELECT 'journal'::text AS type,
    journal_entries.id AS source_id,
    journal_entries.entry_date AS occurred_on,
    journal_entries.entry_time AS occurred_at,
    journal_entries.body AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    "left"((journal_entries.body)::text, 1000) AS preview
   FROM public.journal_entries
UNION ALL
 SELECT 'social'::text AS type,
    social_posts.id AS source_id,
    ((social_posts.posted_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((social_posts.posted_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    COALESCE((first_part.body)::text, ''::text) AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    (social_posts.status)::text AS status,
    social_posts.targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM (public.social_posts
     LEFT JOIN LATERAL ( SELECT social_post_parts.body
           FROM public.social_post_parts
          WHERE (social_post_parts.social_post_id = social_posts.id)
          ORDER BY social_post_parts."position"
         LIMIT 1) first_part ON (true))
  WHERE (social_posts.status = 'posted'::public.social_post_status)
UNION ALL
 SELECT 'webmention'::text AS type,
    webmentions.id AS source_id,
    ((webmentions.received_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((webmentions.received_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    COALESCE(webmentions.author_name, webmentions.author_domain, (webmentions.source_url)::text) AS name,
    ('/writing/'::text || posts.slug) AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    webmentions.excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM (public.webmentions
     JOIN public.posts ON ((posts.id = webmentions.post_id)))
  WHERE (webmentions.status = 'approved'::public.webmention_status)
UNION ALL
 SELECT 'task'::text AS type,
    tasks.id AS source_id,
    ((tasks.completed_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((tasks.completed_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    tasks.title AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    tasks.id AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    COALESCE(( SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object('kind', task_contributors.kind, 'agent', task_contributors.agent, 'model', task_contributors.model)) ORDER BY task_contributors.id) AS jsonb_agg
           FROM public.task_contributors
          WHERE (task_contributors.task_id = tasks.id)), '[{"kind": "owner"}]'::jsonb) AS contributors,
    NULL::text AS preview
   FROM public.tasks
  WHERE (tasks.status = 'done'::public.task_status)
UNION ALL
 SELECT 'project'::text AS type,
    projects.id AS source_id,
    ((projects.created_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((projects.created_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    projects.name,
    projects.url AS link,
    projects.repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
        CASE
            WHEN (projects.archived_on IS NULL) THEN 'active'::text
            ELSE 'archived'::text
        END AS status,
    NULL::public.network[] AS targets,
    projects.tagline AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.projects
UNION ALL
 SELECT 'sprint'::text AS type,
    sprints.id AS source_id,
    sprints.sprint_date AS occurred_on,
    '00:00:00'::time without time zone AS occurred_at,
    (sprints.sprint_date)::text AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.sprints
UNION ALL
 SELECT 'suggestion'::text AS type,
    suggestions.id AS source_id,
    ((suggestions.created_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((suggestions.created_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    COALESCE(posts.title, (first_part.body)::text, ''::text) AS name,
    ('/writing/'::text || posts.slug) AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM ((public.suggestions
     LEFT JOIN public.posts ON ((posts.id = suggestions.post_id)))
     LEFT JOIN LATERAL ( SELECT social_post_parts.body
           FROM public.social_post_parts
          WHERE (social_post_parts.social_post_id = suggestions.social_post_id)
          ORDER BY social_post_parts."position"
         LIMIT 1) first_part ON (true))
UNION ALL
 SELECT 'comment'::text AS type,
    task_comments.id AS source_id,
    ((task_comments.created_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((task_comments.created_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    (task_comments.body)::text AS name,
    task_comments.url AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    tasks.title AS excerpt,
    task_comments.task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    "left"((task_comments.body)::text, 1000) AS preview
   FROM (public.task_comments
     JOIN public.tasks ON ((tasks.id = task_comments.task_id)))
UNION ALL
 SELECT 'decision'::text AS type,
    decision_events.id AS source_id,
    ((decision_events.created_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((decision_events.created_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    (decisions.title)::text AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    (decision_events.kind)::text AS status,
    NULL::public.network[] AS targets,
    (COALESCE(decision_events.reason, decision_events.note, decision_options.title))::text AS excerpt,
    NULL::integer AS task_id,
    decision_events.decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM ((public.decision_events
     JOIN public.decisions ON ((decisions.id = decision_events.decision_id)))
     LEFT JOIN public.decision_options ON ((decision_options.id = decision_events.option_id)))
UNION ALL
 SELECT 'decision_comment'::text AS type,
    decision_comments.id AS source_id,
    ((decision_comments.created_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((decision_comments.created_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    (decision_comments.body)::text AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    (decisions.title)::text AS excerpt,
    NULL::integer AS task_id,
    decision_comments.decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    "left"((decision_comments.body)::text, 1000) AS preview
   FROM (public.decision_comments
     JOIN public.decisions ON ((decisions.id = decision_comments.decision_id)))
UNION ALL
 SELECT 'session'::text AS type,
    work_sessions.id AS source_id,
    ((work_sessions.started_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((work_sessions.started_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    tasks.title AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    work_sessions.task_id,
    NULL::integer AS decision_id,
    (floor(EXTRACT(epoch FROM (work_sessions.ended_at - work_sessions.started_at))))::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM (public.work_sessions
     JOIN public.tasks ON ((tasks.id = work_sessions.task_id)))
  WHERE (work_sessions.ended_at IS NOT NULL)
UNION ALL
 SELECT 'pull_request_opened'::text AS type,
    pull_requests.id AS source_id,
    ((pull_requests.ready_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((pull_requests.ready_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    pull_requests.title AS name,
    pull_requests.url AS link,
    pull_requests.repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.pull_requests
  WHERE (pull_requests.ready_at IS NOT NULL)
UNION ALL
 SELECT
        CASE
            WHEN (pull_requests.merged_at IS NULL) THEN 'pull_request_closed'::text
            ELSE 'pull_request_merged'::text
        END AS type,
    pull_requests.id AS source_id,
    ((COALESCE(pull_requests.merged_at, pull_requests.closed_at) AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((COALESCE(pull_requests.merged_at, pull_requests.closed_at) AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    pull_requests.title AS name,
    pull_requests.url AS link,
    pull_requests.repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    NULL::text AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    NULL::integer AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.pull_requests
  WHERE ((pull_requests.ready_at IS NOT NULL) AND (COALESCE(pull_requests.merged_at, pull_requests.closed_at) IS NOT NULL))
UNION ALL
 SELECT 'workout'::text AS type,
    workouts.id AS source_id,
    ((workouts.started_at AT TIME ZONE 'America/Chicago'::text))::date AS occurred_on,
    ((workouts.started_at AT TIME ZONE 'America/Chicago'::text))::time without time zone AS occurred_at,
    initcap(replace(workouts.kind, '_'::text, ' '::text)) AS name,
    NULL::text AS link,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::integer AS additions,
    NULL::integer AS deletions,
    NULL::text AS status,
    NULL::public.network[] AS targets,
    workouts.device AS excerpt,
    NULL::integer AS task_id,
    NULL::integer AS decision_id,
    (workouts.minutes * 60) AS worked_seconds,
    NULL::jsonb AS contributors,
    NULL::text AS preview
   FROM public.workouts;


--
-- Name: agent_session_index_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_index_lines (
    id integer NOT NULL,
    agent_session_id integer NOT NULL,
    memory_file_id integer,
    path text NOT NULL,
    scope public.memory_scope NOT NULL,
    description public.non_blank_text NOT NULL,
    description_agent public.contributor_slug,
    description_model public.contributor_slug,
    fact_count integer NOT NULL,
    CONSTRAINT agent_session_index_lines_description_author_check CHECK ((num_nonnulls(description_agent, description_model) = ANY (ARRAY[0, 2]))),
    CONSTRAINT agent_session_index_lines_fact_count_check CHECK ((fact_count >= 0))
);


--
-- Name: agent_session_index_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.agent_session_index_lines ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.agent_session_index_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_session_loads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_loads (
    agent_session_id integer NOT NULL,
    memory_file_id integer NOT NULL
);


--
-- Name: agent_session_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_reads (
    id integer NOT NULL,
    agent_session_id integer NOT NULL,
    memory_file_id integer,
    read_at timestamp with time zone NOT NULL
);


--
-- Name: agent_session_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.agent_session_reads ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.agent_session_reads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_session_search_hits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_search_hits (
    id integer NOT NULL,
    agent_session_search_id integer NOT NULL,
    memory_fact_id integer,
    memory_file_id integer,
    text public.non_blank_text NOT NULL,
    path text NOT NULL
);


--
-- Name: agent_session_search_hits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.agent_session_search_hits ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.agent_session_search_hits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_session_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_searches (
    id integer NOT NULL,
    agent_session_id integer NOT NULL,
    searched_at timestamp with time zone NOT NULL,
    query public.non_blank_text NOT NULL,
    scope public.memory_scope,
    repo public.repo_name,
    project_id integer,
    task_id integer
);


--
-- Name: agent_session_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.agent_session_searches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.agent_session_searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_session_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_session_tasks (
    agent_session_id integer NOT NULL,
    task_id integer NOT NULL
);


--
-- Name: agent_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_sessions (
    id integer NOT NULL,
    title public.non_blank_text NOT NULL,
    agent public.contributor_slug NOT NULL,
    model public.contributor_slug NOT NULL,
    client public.non_blank_text,
    repo public.repo_name,
    branch public.non_blank_text,
    started_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ended_at timestamp with time zone,
    project_id integer,
    CONSTRAINT agent_sessions_branch_length_check CHECK ((char_length((branch)::text) <= 255)),
    CONSTRAINT agent_sessions_client_length_check CHECK ((char_length((client)::text) <= 200)),
    CONSTRAINT agent_sessions_title_length_check CHECK ((char_length((title)::text) <= 200))
);


--
-- Name: agent_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.agent_sessions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.agent_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_clicks (
    id integer NOT NULL,
    event_id integer NOT NULL,
    link_host public.hostname NOT NULL,
    link_path public.http_path NOT NULL,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: analytics_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_clicks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_events (
    id integer NOT NULL,
    path public.http_path NOT NULL,
    title text,
    visitor_hash public.visitor_hash NOT NULL,
    address_hash public.visitor_hash NOT NULL,
    view_token public.view_token,
    referrer_host public.hostname,
    country_code public.country_code,
    read_seconds integer DEFAULT 0 NOT NULL,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    month_visitor_hash public.visitor_hash,
    source public.ref_source,
    device_class public.device_class,
    scroll_depth public.scroll_depth DEFAULT 0,
    referrer_path public.http_path,
    country_name text,
    CONSTRAINT analytics_events_read_seconds_check CHECK ((read_seconds >= 0))
);


--
-- Name: analytics_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_clicks (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path NOT NULL,
    link_host public.hostname NOT NULL,
    link_path public.http_path NOT NULL,
    clicks integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_clicks_clicks_check CHECK ((clicks >= 0))
);


--
-- Name: analytics_rollup_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_clicks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_countries (
    id integer NOT NULL,
    day date NOT NULL,
    country_code public.country_code,
    views integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    visitors integer,
    country_name text,
    CONSTRAINT analytics_rollup_countries_views_check CHECK ((views >= 0)),
    CONSTRAINT analytics_rollup_countries_visitors_check CHECK (((visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_countries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_devices (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path,
    device_class public.device_class NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_devices_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_devices ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_hours (
    id integer NOT NULL,
    day date NOT NULL,
    hour smallint NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_hours_hour_check CHECK (((hour >= 0) AND (hour <= 23))),
    CONSTRAINT analytics_rollup_hours_visitors_check CHECK ((visitors >= 0))
);


--
-- Name: analytics_rollup_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_hours ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_page_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_page_countries (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path NOT NULL,
    country_code public.country_code,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    country_name text,
    CONSTRAINT analytics_rollup_page_countries_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_page_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_page_countries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_page_countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_page_referrers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_page_referrers (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path NOT NULL,
    host public.hostname,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_page_referrers_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_page_referrers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_page_referrers ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_page_referrers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_paths; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_paths (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path NOT NULL,
    title text,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    read_seconds integer DEFAULT 0 NOT NULL,
    bounces integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    read_throughs integer,
    CONSTRAINT analytics_rollup_paths_bounces_check CHECK (((bounces >= 0) AND (bounces <= visitors))),
    CONSTRAINT analytics_rollup_paths_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (read_seconds >= 0) AND (visitors <= views))),
    CONSTRAINT analytics_rollup_paths_read_throughs_check CHECK (((read_throughs >= 0) AND (read_throughs <= visitors)))
);


--
-- Name: analytics_rollup_paths_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_paths ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_paths_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_reach; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_reach (
    id integer NOT NULL,
    month date NOT NULL,
    path public.http_path,
    reach integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_reach_month_check CHECK ((EXTRACT(day FROM month) = (1)::numeric)),
    CONSTRAINT analytics_rollup_reach_reach_check CHECK ((reach >= 0))
);


--
-- Name: analytics_rollup_reach_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_reach ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_reach_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_referrers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_referrers (
    id integer NOT NULL,
    day date NOT NULL,
    host public.hostname,
    views integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    visitors integer,
    CONSTRAINT analytics_rollup_referrers_views_check CHECK ((views >= 0)),
    CONSTRAINT analytics_rollup_referrers_visitors_check CHECK (((visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_referrers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_referrers ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_referrers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_scroll_depths; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_scroll_depths (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path NOT NULL,
    scroll_depth public.scroll_depth NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_scroll_depths_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_scroll_depths_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_scroll_depths ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_scroll_depths_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollup_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_sources (
    id integer NOT NULL,
    day date NOT NULL,
    path public.http_path,
    source public.ref_source NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_sources_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (visitors <= views)))
);


--
-- Name: analytics_rollup_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.analytics_rollup_sources ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.analytics_rollup_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: analytics_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollups (
    day date NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    visitors integer DEFAULT 0 NOT NULL,
    read_seconds integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollups_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (read_seconds >= 0) AND (visitors <= views)))
);


--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id integer NOT NULL,
    name public.non_blank_text NOT NULL,
    token_digest text NOT NULL,
    last_used_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scopes public.oauth_scope[] DEFAULT '{read,suggest,write,publish,delete}'::public.oauth_scope[] NOT NULL,
    expires_at timestamp with time zone,
    CONSTRAINT api_tokens_name_length_check CHECK ((char_length((name)::text) <= 100)),
    CONSTRAINT api_tokens_scopes_check CHECK ((cardinality(scopes) > 0))
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.api_tokens ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: artifact_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifact_versions (
    id integer NOT NULL,
    artifact_id integer NOT NULL,
    number integer NOT NULL,
    body public.non_blank_text NOT NULL,
    note public.non_blank_text,
    agent public.contributor_slug,
    model public.contributor_slug,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    session_id integer,
    CONSTRAINT artifact_versions_author_check CHECK ((num_nonnulls(agent, model) = ANY (ARRAY[0, 2]))),
    CONSTRAINT artifact_versions_body_length_check CHECK ((char_length((body)::text) <= 100000)),
    CONSTRAINT artifact_versions_note_length_check CHECK ((char_length((note)::text) <= 200))
);


--
-- Name: artifact_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.artifact_versions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.artifact_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifacts (
    id integer NOT NULL,
    title public.non_blank_text NOT NULL,
    type public.artifact_type NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    title_agent public.contributor_slug,
    title_model public.contributor_slug,
    version integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT artifacts_tags_check CHECK (((cardinality(tags) = 0) OR (array_to_string(tags, ' '::text, '-'::text) ~ '^[a-z0-9]+(-[a-z0-9]+)*( [a-z0-9]+(-[a-z0-9]+)*)*$'::text))),
    CONSTRAINT artifacts_title_author_check CHECK ((num_nonnulls(title_agent, title_model) = ANY (ARRAY[0, 2]))),
    CONSTRAINT artifacts_title_length_check CHECK ((char_length((title)::text) <= 200)),
    CONSTRAINT artifacts_version_check CHECK ((version >= 0))
);


--
-- Name: artifacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.artifacts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.artifacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: known_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.known_devices (
    id integer NOT NULL,
    api_token_id integer,
    oauth_client_id integer,
    browser text,
    os text,
    city text,
    country public.country_code,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    country_name text,
    CONSTRAINT known_devices_credential_check CHECK ((num_nonnulls(api_token_id, oauth_client_id) <= 1))
);


--
-- Name: oauth_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_clients (
    id integer NOT NULL,
    client_id public.non_blank_text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    redirect_uris text[] NOT NULL,
    grant_types text[] NOT NULL,
    response_types text[] NOT NULL,
    token_endpoint_auth_method text DEFAULT 'none'::text NOT NULL,
    visitor_hash public.visitor_hash NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_used_at timestamp with time zone,
    CONSTRAINT oauth_clients_redirect_uris_check CHECK ((cardinality(redirect_uris) > 0))
);


--
-- Name: post_link_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_link_checks (
    id integer NOT NULL,
    post_id integer NOT NULL,
    url text NOT NULL,
    failures integer DEFAULT 0 NOT NULL,
    reason text,
    checked_at timestamp with time zone NOT NULL,
    first_failed_at timestamp with time zone
);


--
-- Name: service_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_connections (
    id integer NOT NULL,
    provider public.non_blank_text NOT NULL,
    host public.non_blank_text,
    account_id public.non_blank_text NOT NULL,
    label public.non_blank_text NOT NULL,
    credentials text NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    revoked_at timestamp with time zone,
    work boolean DEFAULT false NOT NULL,
    lapses_at timestamp with time zone,
    sync_contacts boolean DEFAULT false NOT NULL,
    saves_contacts boolean DEFAULT false NOT NULL,
    CONSTRAINT service_connections_saves_contacts_check CHECK (((NOT saves_contacts) OR sync_contacts))
);


--
-- Name: attention; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.attention AS
 SELECT 'broken_link'::text AS kind,
    post_link_checks.id AS record_id,
    posts.title,
    ((post_link_checks.checked_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count,
    posts.id AS post_id,
    post_link_checks.url,
    post_link_checks.reason,
    post_link_checks.failures
   FROM (public.post_link_checks
     JOIN public.posts ON ((posts.id = post_link_checks.post_id)))
  WHERE (posts.status = 'published'::public.post_status)
UNION ALL
 SELECT 'carried'::text AS kind,
    tasks.id AS record_id,
    (tasks.title)::text AS title,
    ((tasks.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    tasks.carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM public.tasks
  WHERE ((tasks.status <> ALL (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) AND (tasks.carried_count > 0))
UNION ALL
 SELECT 'draft'::text AS kind,
    posts.id AS record_id,
    posts.title,
    ((posts.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM public.posts
  WHERE (posts.status = 'draft'::public.post_status)
UNION ALL
 SELECT 'someday'::text AS kind,
    tasks.id AS record_id,
    (tasks.title)::text AS title,
    ((tasks.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM public.tasks
  WHERE ((tasks.status <> ALL (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) AND (tasks.list = 'someday'::public.task_list))
UNION ALL
 SELECT 'journal'::text AS kind,
    NULL::integer AS record_id,
    NULL::text AS title,
    max(journal_entries.entry_date) AS touched_on,
    NULL::integer AS carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM public.journal_entries
 HAVING (count(*) > 0)
UNION ALL
 SELECT 'new_device'::text AS kind,
    known_devices.id AS record_id,
    format('%s: %s in %s'::text,
        CASE
            WHEN (api_tokens.id IS NOT NULL) THEN ('API token '::text || (api_tokens.name)::text)
            WHEN (oauth_clients.id IS NOT NULL) THEN ('MCP client '::text || COALESCE(NULLIF(btrim(oauth_clients.client_name), ''::text), (oauth_clients.client_id)::text))
            ELSE 'Sign-in'::text
        END, COALESCE(NULLIF(concat_ws(' on '::text, known_devices.browser, known_devices.os), ''::text), 'an unknown device'::text), COALESCE(NULLIF(concat_ws(', '::text, known_devices.city, known_devices.country), ''::text), 'an unknown place'::text)) AS title,
    ((known_devices.created_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM ((public.known_devices
     LEFT JOIN public.api_tokens ON ((api_tokens.id = known_devices.api_token_id)))
     LEFT JOIN public.oauth_clients ON ((oauth_clients.id = known_devices.oauth_client_id)))
  WHERE (EXISTS ( SELECT 1
           FROM public.known_devices earlier
          WHERE ((earlier.id < known_devices.id) AND (NOT (earlier.api_token_id IS DISTINCT FROM known_devices.api_token_id)) AND (NOT (earlier.oauth_client_id IS DISTINCT FROM known_devices.oauth_client_id)))))
UNION ALL
 SELECT 'lapsing'::text AS kind,
    service_connections.id AS record_id,
    (service_connections.label)::text AS title,
    ((service_connections.lapses_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count,
    NULL::integer AS post_id,
    NULL::text AS url,
    NULL::text AS reason,
    NULL::integer AS failures
   FROM public.service_connections
  WHERE (service_connections.lapses_at IS NOT NULL);


--
-- Name: attention_snoozes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attention_snoozes (
    id integer NOT NULL,
    kind public.attention_kind NOT NULL,
    record_id integer,
    ends_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT attention_snoozes_record_check CHECK (((kind = 'journal'::public.attention_kind) = (record_id IS NULL)))
);


--
-- Name: attention_snoozes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.attention_snoozes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.attention_snoozes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_events (
    id integer NOT NULL,
    calendar_id integer NOT NULL,
    google_id text NOT NULL,
    title text,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    place text,
    meet_url text,
    attendees text[] DEFAULT '{}'::text[] NOT NULL,
    notes text,
    link text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    recurring_id text,
    CONSTRAINT calendar_events_days_in_order CHECK ((ends_on >= starts_on))
);


--
-- Name: calendar_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calendar_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calendar_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calendars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendars (
    id integer NOT NULL,
    account public.non_blank_text NOT NULL,
    google_id text NOT NULL,
    name public.non_blank_text NOT NULL,
    writable boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    sync_token text,
    synced_from date
);


--
-- Name: calendars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calendars ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calendars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.commits ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contact_syncs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_syncs (
    google_connection_id integer NOT NULL,
    sync_token public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: decision_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.decision_comments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.decision_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: decision_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.decision_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.decision_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: decision_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.decision_options ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.decision_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: decision_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_tags (
    decision_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT decision_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: decision_timeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.decision_timeline AS
 SELECT 'comment'::text AS kind,
    decision_comments.id AS source_id,
    decision_comments.decision_id,
    decision_comments.created_at AS occurred_at,
    (decision_comments.body)::text AS body,
    NULL::integer AS option_id,
    NULL::text AS reason,
    NULL::text AS note
   FROM public.decision_comments
UNION ALL
 SELECT (decision_events.kind)::text AS kind,
    decision_events.id AS source_id,
    decision_events.decision_id,
    decision_events.created_at AS occurred_at,
    NULL::text AS body,
    decision_events.option_id,
    (decision_events.reason)::text AS reason,
    (decision_events.note)::text AS note
   FROM public.decision_events;


--
-- Name: decisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.decisions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.decisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    browser text,
    os text,
    last_signed_in_at timestamp with time zone NOT NULL,
    signed_out_at timestamp with time zone
);


--
-- Name: feed_reader_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_reader_hashes (
    day date NOT NULL,
    path public.http_path NOT NULL,
    reader_hash public.visitor_hash NOT NULL
);


--
-- Name: feed_readers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_readers (
    day date NOT NULL,
    path public.http_path NOT NULL,
    readers integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT feed_readers_readers_check CHECK ((readers >= 0))
);


--
-- Name: feed_subscribers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_subscribers (
    day date NOT NULL,
    path public.http_path NOT NULL,
    aggregator public.ref_source NOT NULL,
    subscribers integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT feed_subscribers_subscribers_check CHECK ((subscribers >= 0))
);


--
-- Name: health_days; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_days (
    id integer NOT NULL,
    day date NOT NULL,
    minutes_asleep integer,
    bed_at timestamp with time zone,
    woke_at timestamp with time zone,
    resting_heart_rate integer,
    hrv double precision,
    steps integer,
    active_zone_minutes integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: health_days_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.health_days ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.health_days_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: held_health_backfills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.held_health_backfills (
    id integer NOT NULL,
    last_day date NOT NULL,
    held_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: held_health_backfills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.held_health_backfills ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.held_health_backfills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: held_post_follow_ups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.held_post_follow_ups (
    id integer NOT NULL,
    post_id integer NOT NULL,
    follow_up public.post_follow_up NOT NULL,
    requested_at timestamp with time zone NOT NULL
);


--
-- Name: held_post_follow_ups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.held_post_follow_ups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.held_post_follow_ups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: held_title_fetches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.held_title_fetches (
    id integer NOT NULL,
    short_link_id integer NOT NULL,
    held_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: held_title_fetches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.held_title_fetches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.held_title_fetches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: held_webmentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.held_webmentions (
    id integer NOT NULL,
    post_id integer NOT NULL,
    source_url public.non_blank_text NOT NULL,
    target_url public.non_blank_text NOT NULL,
    held_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT held_webmentions_source_url_check CHECK ((octet_length((source_url)::text) <= 2048)),
    CONSTRAINT held_webmentions_target_url_check CHECK ((octet_length((target_url)::text) <= 2048))
);


--
-- Name: held_webmentions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.held_webmentions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.held_webmentions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: journal_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.journal_entries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.journal_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: journal_entry_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entry_tags (
    journal_entry_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT journal_entry_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: known_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.known_devices ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.known_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: link_check_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.link_check_runs (
    id integer NOT NULL,
    started_at timestamp with time zone NOT NULL,
    finished_at timestamp with time zone,
    links_checked integer DEFAULT 0 NOT NULL,
    links_due integer NOT NULL,
    stopped_early boolean GENERATED ALWAYS AS (((finished_at IS NOT NULL) AND (links_checked < links_due))) STORED
);


--
-- Name: link_check_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.link_check_runs ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.link_check_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mail_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_accounts (
    id integer NOT NULL,
    provider public.mail_provider NOT NULL,
    name public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    address public.email_address,
    history_id text,
    shown boolean DEFAULT true NOT NULL,
    sends boolean DEFAULT true NOT NULL,
    signature text,
    settings_synced_at timestamp with time zone,
    backfill_page text,
    backfill_held_at timestamp with time zone
);


--
-- Name: mail_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mail_accounts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mail_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mail_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_attachments (
    mail_message_id integer NOT NULL,
    part_id text NOT NULL,
    filename public.non_blank_text NOT NULL,
    mime_type text NOT NULL,
    size integer NOT NULL
);


--
-- Name: mail_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_labels (
    id integer NOT NULL,
    mail_account_id integer NOT NULL,
    name public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    gmail_id text NOT NULL
);


--
-- Name: mail_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mail_labels ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mail_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mail_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_messages (
    id integer NOT NULL,
    mail_thread_id integer NOT NULL,
    reply_to public.email_address,
    subject public.non_blank_text NOT NULL,
    body public.non_blank_text,
    visitor_hash public.visitor_hash,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((subject)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE((body)::text, ''::text) || ' '::text) || COALESCE((reply_to)::text, ''::text))), 'B'::"char"))) STORED,
    gmail_id text,
    from_name text,
    html_body text,
    draft boolean DEFAULT false NOT NULL
);


--
-- Name: mail_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mail_messages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mail_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mail_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_settings (
    id integer DEFAULT 1 NOT NULL,
    contact_form boolean DEFAULT true NOT NULL,
    people boolean DEFAULT true NOT NULL,
    needs_reply boolean DEFAULT true NOT NULL,
    starred boolean DEFAULT true NOT NULL,
    important boolean DEFAULT false NOT NULL,
    skip_notifications boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT mail_settings_singleton_check CHECK ((id = 1))
);


--
-- Name: mail_thread_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_thread_labels (
    mail_thread_id integer NOT NULL,
    mail_label_id integer NOT NULL
);


--
-- Name: mail_thread_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_thread_tags (
    mail_thread_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT mail_thread_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: mail_threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_threads (
    id integer NOT NULL,
    mail_account_id integer NOT NULL,
    subject public.non_blank_text NOT NULL,
    status public.message_status DEFAULT 'unread'::public.message_status NOT NULL,
    marked_spam_at timestamp with time zone,
    snoozed_until timestamp with time zone,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    gmail_id text,
    starred boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    trashed boolean DEFAULT false NOT NULL,
    sent boolean DEFAULT false NOT NULL,
    category public.mail_category,
    draft boolean DEFAULT false NOT NULL,
    important boolean DEFAULT false NOT NULL,
    CONSTRAINT mail_threads_marked_spam_at_check CHECK (((status = 'spam'::public.message_status) = (marked_spam_at IS NOT NULL)))
);


--
-- Name: mail_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mail_threads ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mail_threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: memory_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_events (
    id integer NOT NULL,
    memory_file_id integer NOT NULL,
    memory_fact_id integer,
    op public.memory_event_op NOT NULL,
    type public.memory_fact_type,
    text text,
    was_type public.memory_fact_type,
    was_text text,
    reverted_event_id integer,
    agent public.contributor_slug,
    model public.contributor_slug,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    session_id integer,
    was_agent public.contributor_slug,
    was_model public.contributor_slug,
    CONSTRAINT memory_events_author_check CHECK ((num_nonnulls(agent, model) = ANY (ARRAY[0, 2]))),
    CONSTRAINT memory_events_op_check CHECK (
CASE (op)::text
    WHEN 'create'::text THEN (num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0)
    WHEN 'scope'::text THEN (num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0)
    WHEN 'describe'::text THEN ((memory_fact_id IS NULL) AND (num_nonnulls(text, was_text) = 2) AND (reverted_event_id IS NULL))
    WHEN 'add'::text THEN ((memory_fact_id IS NOT NULL) AND (text IS NOT NULL) AND (num_nonnulls(was_text, reverted_event_id) = 0))
    WHEN 'edit'::text THEN ((num_nonnulls(memory_fact_id, text, was_text) = 3) AND (reverted_event_id IS NULL))
    WHEN 'remove'::text THEN ((memory_fact_id IS NOT NULL) AND (was_text IS NOT NULL) AND (num_nonnulls(text, reverted_event_id) = 0))
    WHEN 'revert'::text THEN ((reverted_event_id IS NOT NULL) AND (num_nonnulls(text, was_text) > 0))
    ELSE false
END),
    CONSTRAINT memory_events_state_check CHECK (((memory_fact_id IS NULL) OR (((type IS NULL) = (text IS NULL)) AND ((was_type IS NULL) = (was_text IS NULL))))),
    CONSTRAINT memory_events_was_author_check CHECK (((num_nonnulls(was_agent, was_model) = ANY (ARRAY[0, 2])) AND ((was_agent IS NULL) OR (was_text IS NOT NULL))))
);


--
-- Name: memory_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.memory_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.memory_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: memory_facts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_facts (
    id integer NOT NULL,
    memory_file_id integer NOT NULL,
    type public.memory_fact_type NOT NULL,
    text public.non_blank_text NOT NULL,
    agent public.contributor_slug,
    model public.contributor_slug,
    removed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT memory_facts_author_check CHECK ((num_nonnulls(agent, model) = ANY (ARRAY[0, 2])))
);


--
-- Name: memory_facts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.memory_facts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.memory_facts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: memory_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_files (
    id integer NOT NULL,
    path text NOT NULL,
    scope public.memory_scope NOT NULL,
    project_id integer,
    task_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description public.non_blank_text NOT NULL,
    description_agent public.contributor_slug,
    description_model public.contributor_slug,
    CONSTRAINT memory_files_description_author_check CHECK ((num_nonnulls(description_agent, description_model) = ANY (ARRAY[0, 2]))),
    CONSTRAINT memory_files_path_check CHECK ((path ~ '^[\w./-]+\.md$'::text)),
    CONSTRAINT memory_files_scope_check CHECK (
CASE scope
    WHEN 'global'::public.memory_scope THEN (num_nonnulls(project_id, task_id) = 0)
    WHEN 'project'::public.memory_scope THEN ((project_id IS NOT NULL) AND (task_id IS NULL))
    WHEN 'task'::public.memory_scope THEN ((task_id IS NOT NULL) AND (project_id IS NULL))
    ELSE false
END)
);


--
-- Name: memory_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.memory_files ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.memory_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: note_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_folders (
    id integer NOT NULL,
    parent_id integer,
    name public.non_blank_text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: note_folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.note_folders ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.note_folders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: note_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_links (
    note_id integer NOT NULL,
    title public.non_blank_text NOT NULL
);


--
-- Name: note_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_tags (
    note_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT note_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id integer NOT NULL,
    folder_id integer,
    title public.non_blank_text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    pinned boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, (title)::text), 'A'::"char") || setweight(to_tsvector('english'::regconfig, body), 'B'::"char"))) STORED
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.notes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: oauth_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.oauth_clients ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: oauth_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_codes (
    id integer NOT NULL,
    oauth_client_id integer NOT NULL,
    code_digest text NOT NULL,
    redirect_uri text NOT NULL,
    code_challenge text NOT NULL,
    code_challenge_method public.code_challenge_method DEFAULT 'S256'::public.code_challenge_method NOT NULL,
    resource text,
    scopes public.oauth_scope[] DEFAULT '{read}'::public.oauth_scope[] NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    redirect_uri_sent boolean DEFAULT true NOT NULL
);


--
-- Name: oauth_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.oauth_codes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_tokens (
    id integer NOT NULL,
    oauth_client_id integer NOT NULL,
    type public.oauth_token_type NOT NULL,
    token_digest text NOT NULL,
    resource text,
    scopes public.oauth_scope[] DEFAULT '{read}'::public.oauth_scope[] NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    access_token_id integer
);


--
-- Name: oauth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.oauth_tokens ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: owner_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.owner_identities (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    email public.email_address NOT NULL
);


--
-- Name: owner_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.owner_identities ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.owner_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id integer NOT NULL,
    key public.tag_name,
    name public.non_blank_text,
    mastodon_handle public.mastodon_handle,
    bluesky_handle text,
    bluesky_did text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    name_prefix public.non_blank_text,
    given_name public.non_blank_text,
    middle_name public.non_blank_text,
    family_name public.non_blank_text,
    name_suffix public.non_blank_text,
    phonetic_given_name public.non_blank_text,
    phonetic_middle_name public.non_blank_text,
    phonetic_family_name public.non_blank_text,
    nickname public.non_blank_text,
    file_as public.non_blank_text,
    company public.non_blank_text,
    job_title public.non_blank_text,
    department public.non_blank_text,
    notes public.non_blank_text,
    emails jsonb DEFAULT '[]'::jsonb NOT NULL,
    phones jsonb DEFAULT '[]'::jsonb NOT NULL,
    addresses jsonb DEFAULT '[]'::jsonb NOT NULL,
    websites jsonb DEFAULT '[]'::jsonb NOT NULL,
    chats jsonb DEFAULT '[]'::jsonb NOT NULL,
    dates jsonb DEFAULT '[]'::jsonb NOT NULL,
    relations jsonb DEFAULT '[]'::jsonb NOT NULL,
    custom_fields jsonb DEFAULT '[]'::jsonb NOT NULL,
    birthday public.partial_date,
    labels text[] DEFAULT '{}'::text[] NOT NULL,
    starred boolean DEFAULT false NOT NULL,
    google_connection_id integer,
    google_id public.non_blank_text,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, ((COALESCE((name)::text, ''::text) || ' '::text) || COALESCE((company)::text, ''::text))), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((((COALESCE((key)::text, ''::text) || ' '::text) || COALESCE((mastodon_handle)::text, ''::text)) || ' '::text) || COALESCE(bluesky_handle, ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT people_addresses_check CHECK ((jsonb_typeof(addresses) = 'array'::text)),
    CONSTRAINT people_bluesky_did_check CHECK (((bluesky_handle IS NULL) = (bluesky_did IS NULL))),
    CONSTRAINT people_chats_check CHECK ((jsonb_typeof(chats) = 'array'::text)),
    CONSTRAINT people_custom_fields_check CHECK ((jsonb_typeof(custom_fields) = 'array'::text)),
    CONSTRAINT people_dates_check CHECK ((jsonb_typeof(dates) = 'array'::text)),
    CONSTRAINT people_emails_check CHECK ((jsonb_typeof(emails) = 'array'::text)),
    CONSTRAINT people_key_check CHECK (((key IS NOT NULL) OR (num_nonnulls(mastodon_handle, bluesky_handle) = 0))),
    CONSTRAINT people_name_check CHECK ((num_nonnulls(name, company) > 0)),
    CONSTRAINT people_phones_check CHECK ((jsonb_typeof(phones) = 'array'::text)),
    CONSTRAINT people_relations_check CHECK ((jsonb_typeof(relations) = 'array'::text)),
    CONSTRAINT people_websites_check CHECK ((jsonb_typeof(websites) = 'array'::text))
);


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.people ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_jobs (
    id integer NOT NULL,
    job text NOT NULL,
    outcome public.performance_job_outcome NOT NULL,
    duration double precision NOT NULL,
    query_count integer NOT NULL,
    query_time double precision NOT NULL,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    error_class public.non_blank_text,
    error_message text,
    schedule_key public.non_blank_text,
    CONSTRAINT performance_jobs_duration_check CHECK ((duration >= (0)::double precision)),
    CONSTRAINT performance_jobs_query_count_check CHECK ((query_count >= 0)),
    CONSTRAINT performance_jobs_query_time_check CHECK ((query_time >= (0)::double precision))
);


--
-- Name: performance_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_jobs ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_pages (
    id integer NOT NULL,
    route public.http_path NOT NULL,
    device_class public.device_class NOT NULL,
    ttfb double precision NOT NULL,
    dom_content_loaded double precision NOT NULL,
    load double precision NOT NULL,
    lcp double precision,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT performance_pages_dom_content_loaded_check CHECK ((dom_content_loaded >= ttfb)),
    CONSTRAINT performance_pages_lcp_check CHECK ((lcp >= (0)::double precision)),
    CONSTRAINT performance_pages_load_check CHECK ((load >= dom_content_loaded)),
    CONSTRAINT performance_pages_ttfb_check CHECK ((ttfb >= (0)::double precision))
);


--
-- Name: performance_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_pages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_requests (
    id integer NOT NULL,
    route public.http_path,
    verb text NOT NULL,
    status smallint NOT NULL,
    duration double precision NOT NULL,
    query_count integer NOT NULL,
    query_time double precision NOT NULL,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT performance_requests_duration_check CHECK ((duration >= (0)::double precision)),
    CONSTRAINT performance_requests_query_count_check CHECK ((query_count >= 0)),
    CONSTRAINT performance_requests_query_time_check CHECK ((query_time >= (0)::double precision))
);


--
-- Name: performance_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_rollup_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_rollup_jobs (
    id integer NOT NULL,
    day date NOT NULL,
    job text NOT NULL,
    count integer NOT NULL,
    p50 double precision NOT NULL,
    p95 double precision NOT NULL,
    query_count bigint NOT NULL,
    query_time double precision NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT performance_rollup_jobs_figures_check CHECK (((count > 0) AND ((0)::double precision <= p50) AND (p50 <= p95) AND (query_count >= 0) AND (query_time >= (0)::double precision)))
);


--
-- Name: performance_rollup_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_rollup_jobs ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_rollup_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_rollup_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_rollup_pages (
    id integer NOT NULL,
    day date NOT NULL,
    route public.http_path NOT NULL,
    metric public.performance_page_metric NOT NULL,
    count integer NOT NULL,
    p50 double precision NOT NULL,
    p95 double precision NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT performance_rollup_pages_figures_check CHECK (((count > 0) AND ((0)::double precision <= p50) AND (p50 <= p95)))
);


--
-- Name: performance_rollup_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_rollup_pages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_rollup_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_rollup_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_rollup_requests (
    id integer NOT NULL,
    day date NOT NULL,
    route public.http_path,
    verb text NOT NULL,
    count integer NOT NULL,
    p50 double precision NOT NULL,
    p95 double precision NOT NULL,
    query_count bigint NOT NULL,
    query_time double precision NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT performance_rollup_requests_figures_check CHECK (((count > 0) AND ((0)::double precision <= p50) AND (p50 <= p95) AND (query_count >= 0) AND (query_time >= (0)::double precision)))
);


--
-- Name: performance_rollup_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.performance_rollup_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_rollup_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: performance_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.performance_rollups (
    day date NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: photo_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photo_claims (
    photo_id integer NOT NULL,
    owner public.photo_owner NOT NULL,
    owner_id integer NOT NULL
);


--
-- Name: photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photos (
    id integer NOT NULL,
    key public.photo_key NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    byte_size integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    widths integer[] DEFAULT '{}'::integer[] NOT NULL,
    CONSTRAINT photos_size_check CHECK (((width > 0) AND (height > 0) AND (byte_size > 0)))
);


--
-- Name: photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.photos ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: post_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_deletions (
    post_id integer NOT NULL,
    deleted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: post_edits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_edits (
    id integer NOT NULL,
    post_id integer NOT NULL,
    note public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    note_html text NOT NULL,
    CONSTRAINT post_edits_note_length_check CHECK ((char_length((note)::text) <= 500))
);


--
-- Name: post_edits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.post_edits ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.post_edits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: post_link_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.post_link_checks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.post_link_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: post_reader_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_reader_counts (
    path public.http_path NOT NULL,
    readers integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT post_reader_counts_readers_check CHECK ((readers >= 0))
);


--
-- Name: post_reader_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_reader_hashes (
    path public.http_path NOT NULL,
    reader_hash public.visitor_hash NOT NULL
);


--
-- Name: post_tag_removals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_tag_removals (
    post_id integer NOT NULL,
    tag_id integer NOT NULL,
    removed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'public'::public.tag_scope NOT NULL,
    CONSTRAINT post_tags_tag_scope_check CHECK ((tag_scope = 'public'::public.tag_scope))
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.posts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_tags (
    project_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'public'::public.tag_scope NOT NULL,
    CONSTRAINT project_tags_tag_scope_check CHECK ((tag_scope = 'public'::public.tag_scope))
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.projects ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name public.tag_name NOT NULL,
    color public.tag_color NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scope public.tag_scope NOT NULL,
    description text
);


--
-- Name: public_search_documents; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.public_search_documents AS
 SELECT 'post'::text AS kind,
    posts.id AS source_id,
    posts.title,
    ((((COALESCE(posts.title, ''::text) || '
'::text) || COALESCE(posts.summary, ''::text)) || '
'::text) || COALESCE(posts.body, ''::text)) AS body,
    ((posts.published_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    posts.slug,
    NULL::text AS project,
    NULL::integer AS number,
    posts.search_vector
   FROM public.posts
  WHERE (posts.status = 'published'::public.post_status)
UNION ALL
 SELECT 'post'::text AS kind,
    posts.id AS source_id,
    posts.title,
    ((((COALESCE(posts.title, ''::text) || '
'::text) || COALESCE(posts.summary, ''::text)) || '
'::text) || COALESCE(posts.body, ''::text)) AS body,
    ((posts.published_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    posts.slug,
    NULL::text AS project,
    NULL::integer AS number,
    setweight(to_tsvector('english'::regconfig, (tags.name)::text), 'B'::"char") AS search_vector
   FROM ((public.posts
     JOIN public.post_tags ON ((post_tags.post_id = posts.id)))
     JOIN public.tags ON (((tags.id = post_tags.tag_id) AND (tags.scope = 'public'::public.tag_scope))))
  WHERE (posts.status = 'published'::public.post_status)
UNION ALL
 SELECT 'project'::text AS kind,
    projects.id AS source_id,
    (projects.name)::text AS title,
    ((((COALESCE((projects.name)::text, ''::text) || '
'::text) || COALESCE(projects.tagline, ''::text)) || '
'::text) || COALESCE((projects.repo)::text, ''::text)) AS body,
    ((projects.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
        CASE
            WHEN (projects.archived_on IS NULL) THEN 'active'::text
            ELSE 'archived'::text
        END AS status,
    NULL::text AS slug,
    (projects.name)::text AS project,
    NULL::integer AS number,
    projects.search_vector
   FROM public.projects
  WHERE (projects.visibility = 'public'::public.project_visibility)
UNION ALL
 SELECT 'project'::text AS kind,
    projects.id AS source_id,
    (projects.name)::text AS title,
    ((((COALESCE((projects.name)::text, ''::text) || '
'::text) || COALESCE(projects.tagline, ''::text)) || '
'::text) || COALESCE((projects.repo)::text, ''::text)) AS body,
    ((projects.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
        CASE
            WHEN (projects.archived_on IS NULL) THEN 'active'::text
            ELSE 'archived'::text
        END AS status,
    NULL::text AS slug,
    (projects.name)::text AS project,
    NULL::integer AS number,
    setweight(to_tsvector('english'::regconfig, (tags.name)::text), 'B'::"char") AS search_vector
   FROM ((public.projects
     JOIN public.project_tags ON ((project_tags.project_id = projects.id)))
     JOIN public.tags ON (((tags.id = project_tags.tag_id) AND (tags.scope = 'public'::public.tag_scope))))
  WHERE (projects.visibility = 'public'::public.project_visibility)
UNION ALL
 SELECT 'task'::text AS kind,
    tasks.id AS source_id,
    (tasks.title)::text AS title,
    ((COALESCE((tasks.title)::text, ''::text) || '
'::text) || COALESCE(tasks.note, ''::text)) AS body,
    ((COALESCE(tasks.completed_at, tasks.created_at) AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (tasks.status)::text AS status,
    NULL::text AS slug,
    (projects.name)::text AS project,
    tasks.number,
    tasks.search_vector
   FROM (public.tasks
     JOIN public.projects ON ((projects.id = tasks.project_id)))
  WHERE ((projects.visibility = 'public'::public.project_visibility) AND projects.board_published);


--
-- Name: pull_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.pull_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pull_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: record_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.record_links (
    id integer NOT NULL,
    left_kind public.record_kind NOT NULL,
    left_id integer NOT NULL,
    right_kind public.record_kind NOT NULL,
    right_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    relation public.record_link_relation DEFAULT 'related'::public.record_link_relation NOT NULL,
    CONSTRAINT record_links_order_check CHECK ((ROW(left_kind, left_id) < ROW(right_kind, right_id))),
    CONSTRAINT record_links_sourced_from_check CHECK (((relation <> 'sourced_from'::public.record_link_relation) OR ((left_kind = 'task'::public.record_kind) AND (right_kind = 'decision'::public.record_kind)))),
    CONSTRAINT record_links_task_pair_check CHECK ((NOT ((left_kind = 'task'::public.record_kind) AND (right_kind = 'task'::public.record_kind)))),
    CONSTRAINT record_links_task_project_check CHECK ((NOT ((left_kind = 'task'::public.record_kind) AND (right_kind = 'project'::public.record_kind))))
);


--
-- Name: record_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.record_links ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.record_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_events (
    id integer NOT NULL,
    task_id integer NOT NULL,
    kind public.task_event_kind NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    from_list public.task_list,
    to_list public.task_list,
    from_sprint_on date,
    to_sprint_on date,
    tag_name public.tag_name,
    from_status public.task_status,
    to_status public.task_status,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT task_events_kind_check CHECK (
CASE kind
    WHEN 'moved'::public.task_event_kind THEN ((num_nonnulls(from_list, from_sprint_on) = 1) AND (num_nonnulls(to_list, to_sprint_on) = 1) AND ((from_list IS DISTINCT FROM to_list) OR (from_sprint_on IS DISTINCT FROM to_sprint_on)) AND (num_nonnulls(tag_name, from_status, to_status) = 0))
    WHEN 'status_changed'::public.task_event_kind THEN ((from_status IS NOT NULL) AND (to_status IS NOT NULL) AND (from_status <> to_status) AND (num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, tag_name) = 0))
    WHEN 'tagged'::public.task_event_kind THEN ((tag_name IS NOT NULL) AND (num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, from_status, to_status) = 0))
    WHEN 'untagged'::public.task_event_kind THEN ((tag_name IS NOT NULL) AND (num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, from_status, to_status) = 0))
    ELSE (num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, tag_name, from_status, to_status) = 0)
END)
);


--
-- Name: review_carries; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.review_carries AS
 SELECT task_events.id AS event_id,
    task_events.task_id,
    (tasks.title)::text AS title,
    task_events.from_sprint_on AS sprint_date,
    task_events.occurred_at AS carried_at
   FROM (public.task_events
     JOIN public.tasks ON ((tasks.id = task_events.task_id)))
  WHERE ((task_events.kind = 'moved'::public.task_event_kind) AND (task_events.to_sprint_on > task_events.from_sprint_on) AND (task_events.to_sprint_on <= ((task_events.occurred_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: review_decisions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.review_decisions AS
 SELECT decision_events.id AS event_id,
    decision_events.decision_id,
    (decisions.title)::text AS title,
    (decision_events.kind)::text AS outcome,
    (decision_options.title)::text AS chosen,
    (decision_events.reason)::text AS reason,
    ((decision_events.created_at AT TIME ZONE 'America/Chicago'::text))::date AS closed_on,
    decision_events.created_at AS closed_at
   FROM ((public.decision_events
     JOIN public.decisions ON ((decisions.id = decision_events.decision_id)))
     LEFT JOIN public.decision_options ON ((decision_options.id = decision_events.option_id)))
  WHERE (decision_events.kind = ANY (ARRAY['resolved'::public.decision_event_kind, 'dropped'::public.decision_event_kind]));


--
-- Name: review_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_notes (
    id integer NOT NULL,
    period public.review_period NOT NULL,
    starts_on date NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    body public.non_blank_text NOT NULL,
    CONSTRAINT review_notes_starts_on_check CHECK (
CASE period
    WHEN 'week'::public.review_period THEN (EXTRACT(isodow FROM starts_on) = (1)::numeric)
    WHEN 'month'::public.review_period THEN (EXTRACT(day FROM starts_on) = (1)::numeric)
    ELSE NULL::boolean
END)
);


--
-- Name: review_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.review_notes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.review_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: review_tasks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.review_tasks AS
 SELECT id AS task_id,
    (title)::text AS title,
    (status)::text AS status,
    ((completed_at AT TIME ZONE 'America/Chicago'::text))::date AS closed_on,
    worked_seconds,
    COALESCE(( SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object('kind', task_contributors.kind, 'agent', task_contributors.agent, 'model', task_contributors.model)) ORDER BY task_contributors.id) AS jsonb_agg
           FROM public.task_contributors
          WHERE (task_contributors.task_id = tasks.id)), '[{"kind": "owner"}]'::jsonb) AS contributors
   FROM public.tasks;


--
-- Name: saved_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_views (
    id integer NOT NULL,
    name public.non_blank_text NOT NULL,
    screen public.saved_view_screen NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT saved_views_filters_check CHECK ((jsonb_typeof(filters) = 'object'::text)),
    CONSTRAINT saved_views_name_length_check CHECK ((char_length((name)::text) <= 100))
);


--
-- Name: saved_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.saved_views ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.saved_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    filename text NOT NULL
);


--
-- Name: search_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_attempts (
    id integer NOT NULL,
    visitor_hash public.visitor_hash NOT NULL,
    attempted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: search_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.search_attempts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.search_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: work_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_entries (
    id integer NOT NULL,
    org public.non_blank_text NOT NULL,
    role public.non_blank_text NOT NULL,
    blurb text,
    from_year integer NOT NULL,
    to_year integer,
    "position" integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((org)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE((role)::text, ''::text) || ' '::text) || COALESCE(blurb, ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT work_entries_from_year_check CHECK ((from_year > 0)),
    CONSTRAINT work_entries_position_check CHECK (("position" > 0)),
    CONSTRAINT work_entries_to_year_check CHECK (((to_year IS NULL) OR (to_year >= from_year)))
);


--
-- Name: search_documents; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.search_documents AS
 SELECT 'task'::text AS kind,
    tasks.id AS source_id,
    (tasks.title)::text AS title,
    ((COALESCE((tasks.title)::text, ''::text) || '
'::text) || COALESCE(tasks.note, ''::text)) AS body,
    ((COALESCE(tasks.completed_at, tasks.created_at) AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (tasks.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    tasks.search_vector
   FROM public.tasks
UNION ALL
 SELECT 'post'::text AS kind,
    posts.id AS source_id,
    posts.title,
    ((((COALESCE(posts.title, ''::text) || '
'::text) || COALESCE(posts.summary, ''::text)) || '
'::text) || COALESCE(posts.body, ''::text)) AS body,
    ((COALESCE(posts.published_at, posts.created_at) AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (posts.status)::text AS status,
    posts.slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    posts.search_vector
   FROM public.posts
UNION ALL
 SELECT 'social'::text AS kind,
    social_posts.id AS source_id,
    (social_post_parts.body)::text AS title,
    (social_post_parts.body)::text AS body,
    ((COALESCE(social_posts.posted_at, social_posts.created_at) AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (social_posts.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    social_post_parts.search_vector
   FROM (public.social_post_parts
     JOIN public.social_posts ON ((social_posts.id = social_post_parts.social_post_id)))
UNION ALL
 SELECT 'journal'::text AS kind,
    journal_entries.id AS source_id,
    split_part((journal_entries.body)::text, '
'::text, 1) AS title,
    (journal_entries.body)::text AS body,
    journal_entries.entry_date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    journal_entries.search_vector
   FROM public.journal_entries
UNION ALL
 SELECT 'commit'::text AS kind,
    commits.id AS source_id,
    split_part(commits.message, '
'::text, 1) AS title,
    commits.message AS body,
    commits.commit_date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    commits.repo,
    commits.sha,
    NULL::text AS url,
    commits.search_vector
   FROM public.commits
UNION ALL
 SELECT 'project'::text AS kind,
    projects.id AS source_id,
    (projects.name)::text AS title,
    ((((COALESCE((projects.name)::text, ''::text) || '
'::text) || COALESCE(projects.tagline, ''::text)) || '
'::text) || COALESCE((projects.repo)::text, ''::text)) AS body,
    ((projects.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
        CASE
            WHEN (projects.archived_on IS NULL) THEN 'active'::text
            ELSE 'archived'::text
        END AS status,
    NULL::text AS slug,
    (projects.repo)::text AS repo,
    NULL::text AS sha,
    projects.url,
    projects.search_vector
   FROM public.projects
UNION ALL
 SELECT 'work'::text AS kind,
    work_entries.id AS source_id,
    (work_entries.org)::text AS title,
    ((((COALESCE((work_entries.org)::text, ''::text) || '
'::text) || COALESCE((work_entries.role)::text, ''::text)) || '
'::text) || COALESCE(work_entries.blurb, ''::text)) AS body,
    ((work_entries.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    work_entries.search_vector
   FROM public.work_entries
UNION ALL
 SELECT 'person'::text AS kind,
    people.id AS source_id,
    (COALESCE(people.name, people.company))::text AS title,
    ((((((COALESCE((people.name)::text, ''::text) || '
'::text) || COALESCE((people.key)::text, ''::text)) || '
'::text) || COALESCE((people.mastodon_handle)::text, ''::text)) || '
'::text) || COALESCE(people.bluesky_handle, ''::text)) AS body,
    ((people.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    people.search_vector
   FROM public.people
UNION ALL
 SELECT 'webmention'::text AS kind,
    webmentions.id AS source_id,
    COALESCE(webmentions.author_name, webmentions.author_domain, (webmentions.source_url)::text) AS title,
    ((((COALESCE(webmentions.author_name, ''::text) || '
'::text) || COALESCE(webmentions.excerpt, ''::text)) || '
'::text) || COALESCE((webmentions.source_url)::text, ''::text)) AS body,
    ((webmentions.received_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (webmentions.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    (webmentions.source_url)::text AS url,
    webmentions.search_vector
   FROM public.webmentions
UNION ALL
 SELECT 'decision'::text AS kind,
    decisions.id AS source_id,
    (decisions.title)::text AS title,
    ((COALESCE((decisions.title)::text, ''::text) || '
'::text) || COALESCE((decisions.problem)::text, ''::text)) AS body,
    ((decisions.created_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (decisions.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    decisions.search_vector
   FROM public.decisions
UNION ALL
 SELECT 'pull_request'::text AS kind,
    pull_requests.id AS source_id,
    pull_requests.title,
    ((pull_requests.title || '
'::text) || pull_requests.body) AS body,
    ((COALESCE(pull_requests.merged_at, pull_requests.closed_at, pull_requests.ready_at, pull_requests.created_at) AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    pull_requests.repo,
    NULL::text AS sha,
    pull_requests.url,
    pull_requests.search_vector
   FROM public.pull_requests
UNION ALL
 SELECT 'message'::text AS kind,
    mail_threads.id AS source_id,
    (mail_threads.subject)::text AS title,
    ((((COALESCE((mail_messages.subject)::text, ''::text) || '
'::text) || COALESCE((mail_messages.body)::text, ''::text)) || '
'::text) || COALESCE((mail_messages.reply_to)::text, ''::text)) AS body,
    ((mail_messages.received_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (mail_threads.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    mail_messages.search_vector
   FROM (public.mail_messages
     JOIN public.mail_threads ON ((mail_threads.id = mail_messages.mail_thread_id)))
UNION ALL
 SELECT 'note'::text AS kind,
    notes.id AS source_id,
    (notes.title)::text AS title,
    (((notes.title)::text || '
'::text) || notes.body) AS body,
    ((notes.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    NULL::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    notes.search_vector
   FROM public.notes;


--
-- Name: service_apps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_apps (
    id integer NOT NULL,
    provider public.non_blank_text NOT NULL,
    host public.non_blank_text NOT NULL,
    redirect_uri public.non_blank_text NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    credentials text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: service_apps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.service_apps ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.service_apps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: service_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.service_connections ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.service_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: session_validity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_validity (
    id integer DEFAULT 1 NOT NULL,
    valid_after timestamp with time zone DEFAULT '1970-01-01 00:00:00+00'::timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT session_validity_singleton_check CHECK ((id = 1))
);


--
-- Name: share_group_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.share_group_files (
    id integer NOT NULL,
    share_group_id integer,
    key text NOT NULL,
    filename public.non_blank_text NOT NULL,
    content_type text NOT NULL,
    byte_size bigint NOT NULL,
    alt_text text,
    download_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    short_code_id integer,
    preview_key text,
    CONSTRAINT share_group_files_counts_check CHECK (((byte_size >= 0) AND (download_count >= 0))),
    CONSTRAINT share_group_files_key_check CHECK ((key ~ '^[0-9a-f]{32}$'::text)),
    CONSTRAINT share_group_files_owner_check CHECK ((num_nonnulls(short_code_id, share_group_id) = 1)),
    CONSTRAINT share_group_files_preview_key_check CHECK ((preview_key ~ '^[0-9a-f]{32}$'::text))
);


--
-- Name: share_group_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.share_group_files ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.share_group_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: share_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.share_groups (
    id integer NOT NULL,
    short_code_id integer NOT NULL,
    view_count integer DEFAULT 0 NOT NULL,
    zip_download_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    name public.non_blank_text,
    CONSTRAINT share_groups_counts_check CHECK (((view_count >= 0) AND (zip_download_count >= 0)))
);


--
-- Name: share_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.share_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.share_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: short_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.short_codes (
    id integer NOT NULL,
    code public.short_code NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: short_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.short_codes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.short_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: short_link_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.short_link_checks (
    id integer NOT NULL,
    short_link_id integer NOT NULL,
    url text NOT NULL,
    failures integer DEFAULT 0 NOT NULL,
    reason text,
    checked_at timestamp with time zone NOT NULL,
    first_failed_at timestamp with time zone
);


--
-- Name: short_link_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.short_link_checks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.short_link_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: short_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.short_links (
    id integer NOT NULL,
    short_code_id integer NOT NULL,
    destination text NOT NULL,
    title text,
    click_count integer DEFAULT 0 NOT NULL,
    last_clicked_at timestamp with time zone,
    retargeted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT short_links_click_count_check CHECK ((click_count >= 0)),
    CONSTRAINT short_links_destination_check CHECK ((destination ~ '^https?://[^\s/?#]+([/?#]\S*)?$'::text))
);


--
-- Name: short_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.short_links ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.short_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sightings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sightings (
    id integer NOT NULL,
    api_token_id integer,
    oauth_client_id integer,
    browser text,
    os text,
    city text,
    country public.country_code,
    calls integer DEFAULT 1 NOT NULL,
    last_address text NOT NULL,
    last_user_agent text NOT NULL,
    first_seen_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    country_name text,
    product text,
    CONSTRAINT sightings_credential_check CHECK ((num_nonnulls(api_token_id, oauth_client_id) = 1)),
    CONSTRAINT sightings_last_user_agent_length CHECK ((length(last_user_agent) <= 1024))
);


--
-- Name: sightings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sightings ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.sightings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sign_ins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sign_ins (
    id integer NOT NULL,
    outcome public.sign_in_outcome NOT NULL,
    address text NOT NULL,
    user_agent text NOT NULL,
    browser text,
    os text,
    city text,
    country public.country_code,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    country_name text,
    provider public.sign_in_provider NOT NULL,
    visitor_hash public.visitor_hash,
    device_id uuid,
    dismissed_at timestamp with time zone,
    CONSTRAINT sign_ins_user_agent_length CHECK ((length(user_agent) <= 1024))
);


--
-- Name: sign_ins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sign_ins ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.sign_ins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_post_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_post_deliveries (
    id integer NOT NULL,
    social_post_id integer NOT NULL,
    network public.network NOT NULL,
    remote_ids text[] DEFAULT '{}'::text[] NOT NULL,
    remote_url public.non_blank_text,
    error text,
    failed boolean DEFAULT false NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    repost_count integer DEFAULT 0 NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    connection_id integer,
    CONSTRAINT social_post_deliveries_counts_check CHECK (((like_count >= 0) AND (repost_count >= 0) AND (reply_count >= 0)))
);


--
-- Name: social_post_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.social_post_deliveries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.social_post_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_post_parts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.social_post_parts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.social_post_parts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_post_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_post_photos (
    id integer NOT NULL,
    social_post_part_id integer NOT NULL,
    "position" integer NOT NULL,
    photo_key public.photo_key NOT NULL,
    alt_text public.non_blank_text,
    CONSTRAINT social_post_photos_position_check CHECK ((("position" >= 1) AND ("position" <= 4)))
);


--
-- Name: social_post_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.social_post_photos ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.social_post_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.social_posts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.social_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: spam_senders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spam_senders (
    reply_to public.email_address NOT NULL,
    marked_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT spam_senders_reply_to_lower_check CHECK (((reply_to)::text = lower((reply_to)::text)))
);


--
-- Name: sprints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sprints ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.sprints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: suggestion_edits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suggestion_edits (
    id integer NOT NULL,
    suggestion_id integer NOT NULL,
    "position" integer NOT NULL,
    part integer,
    original public.non_blank_text NOT NULL,
    replacement text NOT NULL,
    reason public.non_blank_text NOT NULL,
    status public.suggestion_edit_status DEFAULT 'pending'::public.suggestion_edit_status NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT suggestion_edits_part_check CHECK (((part IS NULL) OR (part > 0))),
    CONSTRAINT suggestion_edits_position_check CHECK (("position" > 0))
);


--
-- Name: suggestion_edits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.suggestion_edits ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.suggestion_edits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: suggestions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.suggestions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.suggestions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sync_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_states (
    id integer NOT NULL,
    kind public.sync_state_kind NOT NULL,
    sync public.sync_name,
    repo text,
    synced_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    failure_reason text,
    failure_message text,
    failing_since timestamp with time zone,
    failure_count integer DEFAULT 0 NOT NULL
);


--
-- Name: sync_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sync_states ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.sync_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tags ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_comments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_contributors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_contributors ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_contributors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_links (
    id integer NOT NULL,
    from_task_id integer NOT NULL,
    to_task_id integer NOT NULL,
    type public.task_link_type NOT NULL,
    synced boolean DEFAULT false NOT NULL,
    CONSTRAINT task_links_distinct_check CHECK ((from_task_id <> to_task_id))
);


--
-- Name: task_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_links ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_number_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_number_counters (
    id integer NOT NULL,
    project_id integer,
    last_number integer NOT NULL,
    CONSTRAINT task_number_counters_last_number_check CHECK ((last_number > 0))
);


--
-- Name: task_number_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_number_counters ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_number_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_rule_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_rule_projects (
    task_rule_id integer NOT NULL,
    project_id integer NOT NULL
);


--
-- Name: task_rule_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_rule_tags (
    task_rule_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT task_rule_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: task_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_rules (
    id integer NOT NULL,
    pattern public.repo_pattern NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    provider public.task_source_provider NOT NULL
);


--
-- Name: task_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_rules ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_series; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_series (
    id integer NOT NULL,
    task_id integer NOT NULL,
    cadence public.task_cadence NOT NULL,
    every smallint,
    weekday smallint,
    week smallint,
    day smallint,
    month smallint,
    starts_on date,
    paused boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT task_series_cadence_check CHECK (
CASE cadence
    WHEN 'days'::public.task_cadence THEN (every IS NOT NULL)
    WHEN 'weeks'::public.task_cadence THEN ((every IS NOT NULL) AND (weekday IS NOT NULL) AND (starts_on IS NOT NULL))
    WHEN 'month_day'::public.task_cadence THEN (day IS NOT NULL)
    WHEN 'month_weekday'::public.task_cadence THEN ((week IS NOT NULL) AND (weekday IS NOT NULL))
    WHEN 'yearly'::public.task_cadence THEN ((month IS NOT NULL) AND (day IS NOT NULL))
    ELSE true
END),
    CONSTRAINT task_series_day_check CHECK (((day >= 1) AND (day <= 31))),
    CONSTRAINT task_series_every_check CHECK ((every > 0)),
    CONSTRAINT task_series_month_check CHECK (((month >= 1) AND (month <= 12))),
    CONSTRAINT task_series_week_check CHECK ((week = ANY (ARRAY['-1'::integer, 1, 2, 3, 4]))),
    CONSTRAINT task_series_weekday_check CHECK (((weekday >= 0) AND (weekday <= 6)))
);


--
-- Name: task_series_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_series ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_sources (
    id integer NOT NULL,
    task_id integer NOT NULL,
    provider public.task_source_provider NOT NULL,
    remote_id text NOT NULL,
    url text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    remote_state public.task_source_state DEFAULT 'open'::public.task_source_state NOT NULL,
    checked_at timestamp with time zone,
    seen_at timestamp with time zone,
    snoozed_until timestamp with time zone,
    history_cursor timestamp with time zone
);


--
-- Name: task_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.task_sources ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.task_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: task_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_tags (
    task_id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_scope public.tag_scope DEFAULT 'private'::public.tag_scope NOT NULL,
    CONSTRAINT task_tags_tag_scope_check CHECK ((tag_scope = 'private'::public.tag_scope))
);


--
-- Name: task_timeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.task_timeline AS
 SELECT 'comment'::text AS kind,
    task_comments.id AS source_id,
    task_comments.task_id,
    task_comments.created_at AS occurred_at,
    NULL::timestamp with time zone AS ended_at,
    (task_comments.body)::text AS body,
    task_comments.author,
    task_comments.provider,
    task_comments.remote_id,
    task_comments.url,
    NULL::public.task_list AS from_list,
    NULL::public.task_list AS to_list,
    NULL::date AS from_sprint_on,
    NULL::date AS to_sprint_on,
    NULL::text AS tag_name,
    NULL::public.task_status AS from_status,
    NULL::public.task_status AS to_status
   FROM public.task_comments
UNION ALL
 SELECT 'session'::text AS kind,
    work_sessions.id AS source_id,
    work_sessions.task_id,
    work_sessions.started_at AS occurred_at,
    work_sessions.ended_at,
    NULL::text AS body,
    NULL::text AS author,
    NULL::public.task_source_provider AS provider,
    NULL::text AS remote_id,
    NULL::text AS url,
    NULL::public.task_list AS from_list,
    NULL::public.task_list AS to_list,
    NULL::date AS from_sprint_on,
    NULL::date AS to_sprint_on,
    NULL::text AS tag_name,
    NULL::public.task_status AS from_status,
    NULL::public.task_status AS to_status
   FROM public.work_sessions
UNION ALL
 SELECT (task_events.kind)::text AS kind,
    task_events.id AS source_id,
    task_events.task_id,
    task_events.occurred_at,
    NULL::timestamp with time zone AS ended_at,
    NULL::text AS body,
    NULL::text AS author,
    NULL::public.task_source_provider AS provider,
    NULL::text AS remote_id,
    NULL::text AS url,
    task_events.from_list,
    task_events.to_list,
    task_events.from_sprint_on,
    task_events.to_sprint_on,
    (task_events.tag_name)::text AS tag_name,
    task_events.from_status,
    task_events.to_status
   FROM public.task_events;


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tasks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: trusted_authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trusted_authors (
    author_url text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: webmention_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webmention_receipts (
    id integer NOT NULL,
    post_id integer NOT NULL,
    source_url public.non_blank_text NOT NULL,
    visitor_hash public.visitor_hash NOT NULL,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT webmention_receipts_source_url_check CHECK ((octet_length((source_url)::text) <= 2048))
);


--
-- Name: webmention_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.webmention_receipts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.webmention_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: webmention_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webmention_settings (
    id integer DEFAULT 1 NOT NULL,
    receive boolean DEFAULT true NOT NULL,
    send_on_publish boolean DEFAULT true NOT NULL,
    auto_approve_known_authors boolean DEFAULT true NOT NULL,
    enable_on_new_posts boolean DEFAULT true NOT NULL,
    accept_bridgy boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    single_author_hosts text[] DEFAULT '{}'::text[] NOT NULL,
    auto_approve_likes boolean DEFAULT true NOT NULL,
    auto_approve_reposts boolean DEFAULT true NOT NULL,
    CONSTRAINT webmention_settings_singleton_check CHECK ((id = 1))
);


--
-- Name: webmentions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.webmentions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.webmentions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: work_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.work_entries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.work_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: work_session_days; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_session_days AS
 WITH sessions AS (
         SELECT work_sessions.started_at,
            COALESCE(work_sessions.ended_at, now()) AS ended_at
           FROM public.work_sessions
        ), marked AS (
         SELECT sessions.started_at,
            sessions.ended_at,
                CASE
                    WHEN (sessions.started_at <= max(sessions.ended_at) OVER (ORDER BY sessions.started_at, sessions.ended_at ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)) THEN 0
                    ELSE 1
                END AS starts
           FROM sessions
        ), numbered AS (
         SELECT marked.started_at,
            marked.ended_at,
            sum(marked.starts) OVER (ORDER BY marked.started_at, marked.ended_at ROWS UNBOUNDED PRECEDING) AS span
           FROM marked
        ), spans AS (
         SELECT min(numbered.started_at) AS started_at,
            max(numbered.ended_at) AS ended_at
           FROM numbered
          GROUP BY numbered.span
        ), closed AS (
         SELECT work_sessions.task_id,
            (sum(floor(EXTRACT(epoch FROM (work_sessions.ended_at - work_sessions.started_at)))))::integer AS seconds,
            max(work_sessions.ended_at) AS ended_at
           FROM public.work_sessions
          WHERE (work_sessions.ended_at IS NOT NULL)
          GROUP BY work_sessions.task_id
        )
 SELECT (days.day)::date AS worked_on,
    (floor(EXTRACT(epoch FROM (LEAST(spans.ended_at, ((days.day + '1 day'::interval) AT TIME ZONE 'America/Chicago'::text)) - GREATEST(spans.started_at, (days.day AT TIME ZONE 'America/Chicago'::text))))))::integer AS seconds
   FROM (spans
     CROSS JOIN LATERAL generate_series((((spans.started_at AT TIME ZONE 'America/Chicago'::text))::date)::timestamp without time zone, (((spans.ended_at AT TIME ZONE 'America/Chicago'::text))::date)::timestamp without time zone, '1 day'::interval) days(day))
UNION ALL
 SELECT ((COALESCE(tasks.completed_at, closed.ended_at) AT TIME ZONE 'America/Chicago'::text))::date AS worked_on,
    (tasks.worked_seconds - COALESCE(closed.seconds, 0)) AS seconds
   FROM (public.tasks
     LEFT JOIN closed ON ((closed.task_id = tasks.id)))
  WHERE ((tasks.worked_seconds > COALESCE(closed.seconds, 0)) AND (COALESCE(tasks.completed_at, closed.ended_at) IS NOT NULL));


--
-- Name: work_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.work_sessions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.work_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.workouts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_session_index_lines agent_session_index_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_index_lines
    ADD CONSTRAINT agent_session_index_lines_pkey PRIMARY KEY (id);


--
-- Name: agent_session_loads agent_session_loads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_loads
    ADD CONSTRAINT agent_session_loads_pkey PRIMARY KEY (agent_session_id, memory_file_id);


--
-- Name: agent_session_reads agent_session_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_reads
    ADD CONSTRAINT agent_session_reads_pkey PRIMARY KEY (id);


--
-- Name: agent_session_search_hits agent_session_search_hits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_search_hits
    ADD CONSTRAINT agent_session_search_hits_pkey PRIMARY KEY (id);


--
-- Name: agent_session_searches agent_session_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_searches
    ADD CONSTRAINT agent_session_searches_pkey PRIMARY KEY (id);


--
-- Name: agent_session_tasks agent_session_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_tasks
    ADD CONSTRAINT agent_session_tasks_pkey PRIMARY KEY (agent_session_id, task_id);


--
-- Name: agent_sessions agent_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_sessions
    ADD CONSTRAINT agent_sessions_pkey PRIMARY KEY (id);


--
-- Name: analytics_clicks analytics_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_clicks
    ADD CONSTRAINT analytics_clicks_pkey PRIMARY KEY (id);


--
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_clicks analytics_rollup_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_clicks
    ADD CONSTRAINT analytics_rollup_clicks_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_countries analytics_rollup_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_countries
    ADD CONSTRAINT analytics_rollup_countries_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_devices analytics_rollup_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_devices
    ADD CONSTRAINT analytics_rollup_devices_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_hours analytics_rollup_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_hours
    ADD CONSTRAINT analytics_rollup_hours_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_page_countries analytics_rollup_page_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_page_countries
    ADD CONSTRAINT analytics_rollup_page_countries_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_page_referrers analytics_rollup_page_referrers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_page_referrers
    ADD CONSTRAINT analytics_rollup_page_referrers_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_paths analytics_rollup_paths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_paths
    ADD CONSTRAINT analytics_rollup_paths_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_reach analytics_rollup_reach_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_reach
    ADD CONSTRAINT analytics_rollup_reach_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_referrers analytics_rollup_referrers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_referrers
    ADD CONSTRAINT analytics_rollup_referrers_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_scroll_depths analytics_rollup_scroll_depths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_scroll_depths
    ADD CONSTRAINT analytics_rollup_scroll_depths_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_sources analytics_rollup_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_sources
    ADD CONSTRAINT analytics_rollup_sources_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollups analytics_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollups
    ADD CONSTRAINT analytics_rollups_pkey PRIMARY KEY (day);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: artifact_versions artifact_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_versions
    ADD CONSTRAINT artifact_versions_pkey PRIMARY KEY (id);


--
-- Name: artifacts artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT artifacts_pkey PRIMARY KEY (id);


--
-- Name: attention_snoozes attention_snoozes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attention_snoozes
    ADD CONSTRAINT attention_snoozes_pkey PRIMARY KEY (id);


--
-- Name: calendar_events calendar_events_calendar_id_google_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_calendar_id_google_id_key UNIQUE (calendar_id, google_id);


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);


--
-- Name: calendars calendars_account_google_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendars
    ADD CONSTRAINT calendars_account_google_id_key UNIQUE (account, google_id);


--
-- Name: calendars calendars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendars
    ADD CONSTRAINT calendars_pkey PRIMARY KEY (id);


--
-- Name: commits commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (id);


--
-- Name: commits commits_sha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commits
    ADD CONSTRAINT commits_sha_key UNIQUE (sha);


--
-- Name: contact_syncs contact_syncs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_syncs
    ADD CONSTRAINT contact_syncs_pkey PRIMARY KEY (google_connection_id);


--
-- Name: decision_comments decision_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_comments
    ADD CONSTRAINT decision_comments_pkey PRIMARY KEY (id);


--
-- Name: decision_events decision_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT decision_events_pkey PRIMARY KEY (id);


--
-- Name: decision_options decision_options_decision_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT decision_options_decision_id_id_key UNIQUE (decision_id, id);


--
-- Name: decision_options decision_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT decision_options_pkey PRIMARY KEY (id);


--
-- Name: decision_tags decision_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_tags
    ADD CONSTRAINT decision_tags_pkey PRIMARY KEY (decision_id, tag_id);


--
-- Name: decisions decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: feed_reader_hashes feed_reader_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_reader_hashes
    ADD CONSTRAINT feed_reader_hashes_pkey PRIMARY KEY (day, path, reader_hash);


--
-- Name: feed_readers feed_readers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_readers
    ADD CONSTRAINT feed_readers_pkey PRIMARY KEY (day, path);


--
-- Name: feed_subscribers feed_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_subscribers
    ADD CONSTRAINT feed_subscribers_pkey PRIMARY KEY (day, path, aggregator);


--
-- Name: health_days health_days_day_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_days
    ADD CONSTRAINT health_days_day_key UNIQUE (day);


--
-- Name: health_days health_days_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_days
    ADD CONSTRAINT health_days_pkey PRIMARY KEY (id);


--
-- Name: held_health_backfills held_health_backfills_last_day_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_health_backfills
    ADD CONSTRAINT held_health_backfills_last_day_key UNIQUE (last_day);


--
-- Name: held_health_backfills held_health_backfills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_health_backfills
    ADD CONSTRAINT held_health_backfills_pkey PRIMARY KEY (id);


--
-- Name: held_post_follow_ups held_post_follow_ups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_post_follow_ups
    ADD CONSTRAINT held_post_follow_ups_pkey PRIMARY KEY (id);


--
-- Name: held_title_fetches held_title_fetches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_title_fetches
    ADD CONSTRAINT held_title_fetches_pkey PRIMARY KEY (id);


--
-- Name: held_title_fetches held_title_fetches_short_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_title_fetches
    ADD CONSTRAINT held_title_fetches_short_link_id_key UNIQUE (short_link_id);


--
-- Name: held_webmentions held_webmentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_webmentions
    ADD CONSTRAINT held_webmentions_pkey PRIMARY KEY (id);


--
-- Name: journal_entries journal_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);


--
-- Name: journal_entry_tags journal_entry_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_tags
    ADD CONSTRAINT journal_entry_tags_pkey PRIMARY KEY (journal_entry_id, tag_id);


--
-- Name: known_devices known_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.known_devices
    ADD CONSTRAINT known_devices_pkey PRIMARY KEY (id);


--
-- Name: link_check_runs link_check_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.link_check_runs
    ADD CONSTRAINT link_check_runs_pkey PRIMARY KEY (id);


--
-- Name: mail_accounts mail_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_accounts
    ADD CONSTRAINT mail_accounts_pkey PRIMARY KEY (id);


--
-- Name: mail_attachments mail_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_attachments
    ADD CONSTRAINT mail_attachments_pkey PRIMARY KEY (mail_message_id, part_id);


--
-- Name: mail_labels mail_labels_mail_account_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_labels
    ADD CONSTRAINT mail_labels_mail_account_id_name_key UNIQUE (mail_account_id, name) DEFERRABLE;


--
-- Name: mail_labels mail_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_labels
    ADD CONSTRAINT mail_labels_pkey PRIMARY KEY (id);


--
-- Name: mail_messages mail_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_messages
    ADD CONSTRAINT mail_messages_pkey PRIMARY KEY (id);


--
-- Name: mail_settings mail_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_settings
    ADD CONSTRAINT mail_settings_pkey PRIMARY KEY (id);


--
-- Name: mail_thread_labels mail_thread_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_labels
    ADD CONSTRAINT mail_thread_labels_pkey PRIMARY KEY (mail_thread_id, mail_label_id);


--
-- Name: mail_thread_tags mail_thread_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_tags
    ADD CONSTRAINT mail_thread_tags_pkey PRIMARY KEY (mail_thread_id, tag_id);


--
-- Name: mail_threads mail_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_threads
    ADD CONSTRAINT mail_threads_pkey PRIMARY KEY (id);


--
-- Name: memory_events memory_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_events
    ADD CONSTRAINT memory_events_pkey PRIMARY KEY (id);


--
-- Name: memory_facts memory_facts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_facts
    ADD CONSTRAINT memory_facts_pkey PRIMARY KEY (id);


--
-- Name: memory_files memory_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_files
    ADD CONSTRAINT memory_files_pkey PRIMARY KEY (id);


--
-- Name: note_folders note_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_folders
    ADD CONSTRAINT note_folders_pkey PRIMARY KEY (id);


--
-- Name: note_tags note_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_tags
    ADD CONSTRAINT note_tags_pkey PRIMARY KEY (note_id, tag_id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_codes oauth_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_pkey PRIMARY KEY (id);


--
-- Name: oauth_tokens oauth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: owner_identities owner_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_identities
    ADD CONSTRAINT owner_identities_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: performance_jobs performance_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_jobs
    ADD CONSTRAINT performance_jobs_pkey PRIMARY KEY (id);


--
-- Name: performance_pages performance_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_pages
    ADD CONSTRAINT performance_pages_pkey PRIMARY KEY (id);


--
-- Name: performance_requests performance_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_requests
    ADD CONSTRAINT performance_requests_pkey PRIMARY KEY (id);


--
-- Name: performance_rollup_jobs performance_rollup_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_jobs
    ADD CONSTRAINT performance_rollup_jobs_pkey PRIMARY KEY (id);


--
-- Name: performance_rollup_pages performance_rollup_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_pages
    ADD CONSTRAINT performance_rollup_pages_pkey PRIMARY KEY (id);


--
-- Name: performance_rollup_requests performance_rollup_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_requests
    ADD CONSTRAINT performance_rollup_requests_pkey PRIMARY KEY (id);


--
-- Name: performance_rollups performance_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollups
    ADD CONSTRAINT performance_rollups_pkey PRIMARY KEY (day);


--
-- Name: photo_claims photo_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_claims
    ADD CONSTRAINT photo_claims_pkey PRIMARY KEY (owner, owner_id, photo_id);


--
-- Name: photos photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT photos_pkey PRIMARY KEY (id);


--
-- Name: post_deletions post_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_deletions
    ADD CONSTRAINT post_deletions_pkey PRIMARY KEY (post_id);


--
-- Name: post_edits post_edits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_edits
    ADD CONSTRAINT post_edits_pkey PRIMARY KEY (id);


--
-- Name: post_link_checks post_link_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_link_checks
    ADD CONSTRAINT post_link_checks_pkey PRIMARY KEY (id);


--
-- Name: post_reader_counts post_reader_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reader_counts
    ADD CONSTRAINT post_reader_counts_pkey PRIMARY KEY (path);


--
-- Name: post_reader_hashes post_reader_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reader_hashes
    ADD CONSTRAINT post_reader_hashes_pkey PRIMARY KEY (path, reader_hash);


--
-- Name: post_tag_removals post_tag_removals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_removals
    ADD CONSTRAINT post_tag_removals_pkey PRIMARY KEY (post_id, tag_id);


--
-- Name: post_tags post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (post_id, tag_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: posts posts_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_slug_key UNIQUE (slug);


--
-- Name: project_tags project_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_pkey PRIMARY KEY (project_id, tag_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: pull_requests pull_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pull_requests
    ADD CONSTRAINT pull_requests_pkey PRIMARY KEY (id);


--
-- Name: record_links record_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.record_links
    ADD CONSTRAINT record_links_pkey PRIMARY KEY (id);


--
-- Name: review_notes review_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_notes
    ADD CONSTRAINT review_notes_pkey PRIMARY KEY (id);


--
-- Name: saved_views saved_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_views
    ADD CONSTRAINT saved_views_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: search_attempts search_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_attempts
    ADD CONSTRAINT search_attempts_pkey PRIMARY KEY (id);


--
-- Name: service_apps service_apps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_apps
    ADD CONSTRAINT service_apps_pkey PRIMARY KEY (id);


--
-- Name: service_connections service_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_connections
    ADD CONSTRAINT service_connections_pkey PRIMARY KEY (id);


--
-- Name: session_validity session_validity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_validity
    ADD CONSTRAINT session_validity_pkey PRIMARY KEY (id);


--
-- Name: share_group_files share_group_files_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_key_key UNIQUE (key);


--
-- Name: share_group_files share_group_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_pkey PRIMARY KEY (id);


--
-- Name: share_group_files share_group_files_preview_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_preview_key_key UNIQUE (preview_key);


--
-- Name: share_group_files share_group_files_short_code_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_short_code_id_key UNIQUE (short_code_id);


--
-- Name: share_groups share_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_groups
    ADD CONSTRAINT share_groups_pkey PRIMARY KEY (id);


--
-- Name: share_groups share_groups_short_code_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_groups
    ADD CONSTRAINT share_groups_short_code_id_key UNIQUE (short_code_id);


--
-- Name: short_codes short_codes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_codes
    ADD CONSTRAINT short_codes_code_key UNIQUE (code);


--
-- Name: short_codes short_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_codes
    ADD CONSTRAINT short_codes_pkey PRIMARY KEY (id);


--
-- Name: short_link_checks short_link_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_link_checks
    ADD CONSTRAINT short_link_checks_pkey PRIMARY KEY (id);


--
-- Name: short_link_checks short_link_checks_short_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_link_checks
    ADD CONSTRAINT short_link_checks_short_link_id_key UNIQUE (short_link_id);


--
-- Name: short_links short_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_links
    ADD CONSTRAINT short_links_pkey PRIMARY KEY (id);


--
-- Name: short_links short_links_short_code_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_links
    ADD CONSTRAINT short_links_short_code_id_key UNIQUE (short_code_id);


--
-- Name: sightings sightings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sightings
    ADD CONSTRAINT sightings_pkey PRIMARY KEY (id);


--
-- Name: sign_ins sign_ins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sign_ins
    ADD CONSTRAINT sign_ins_pkey PRIMARY KEY (id);


--
-- Name: social_post_deliveries social_post_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_deliveries
    ADD CONSTRAINT social_post_deliveries_pkey PRIMARY KEY (id);


--
-- Name: social_post_parts social_post_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_parts
    ADD CONSTRAINT social_post_parts_pkey PRIMARY KEY (id);


--
-- Name: social_post_photos social_post_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_photos
    ADD CONSTRAINT social_post_photos_pkey PRIMARY KEY (id);


--
-- Name: social_posts social_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_posts
    ADD CONSTRAINT social_posts_pkey PRIMARY KEY (id);


--
-- Name: spam_senders spam_senders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spam_senders
    ADD CONSTRAINT spam_senders_pkey PRIMARY KEY (reply_to);


--
-- Name: sprints sprints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sprints
    ADD CONSTRAINT sprints_pkey PRIMARY KEY (id);


--
-- Name: suggestion_edits suggestion_edits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggestion_edits
    ADD CONSTRAINT suggestion_edits_pkey PRIMARY KEY (id);


--
-- Name: suggestions suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_pkey PRIMARY KEY (id);


--
-- Name: sync_states sync_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_states
    ADD CONSTRAINT sync_states_pkey PRIMARY KEY (id);


--
-- Name: tags tags_id_scope_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_id_scope_key UNIQUE (id, scope);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: tags tags_scope_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_scope_name_key UNIQUE (scope, name);


--
-- Name: task_comments task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_pkey PRIMARY KEY (id);


--
-- Name: task_contributors task_contributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_contributors
    ADD CONSTRAINT task_contributors_pkey PRIMARY KEY (id);


--
-- Name: task_events task_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_pkey PRIMARY KEY (id);


--
-- Name: task_links task_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_links
    ADD CONSTRAINT task_links_pkey PRIMARY KEY (id);


--
-- Name: task_number_counters task_number_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_number_counters
    ADD CONSTRAINT task_number_counters_pkey PRIMARY KEY (id);


--
-- Name: task_rule_projects task_rule_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_projects
    ADD CONSTRAINT task_rule_projects_pkey PRIMARY KEY (task_rule_id, project_id);


--
-- Name: task_rule_tags task_rule_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_tags
    ADD CONSTRAINT task_rule_tags_pkey PRIMARY KEY (task_rule_id, tag_id);


--
-- Name: task_rules task_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rules
    ADD CONSTRAINT task_rules_pkey PRIMARY KEY (id);


--
-- Name: task_series task_series_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_series
    ADD CONSTRAINT task_series_pkey PRIMARY KEY (id);


--
-- Name: task_series task_series_task_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_series
    ADD CONSTRAINT task_series_task_id_key UNIQUE (task_id);


--
-- Name: task_sources task_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_sources
    ADD CONSTRAINT task_sources_pkey PRIMARY KEY (id);


--
-- Name: task_tags task_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_pkey PRIMARY KEY (task_id, tag_id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: trusted_authors trusted_authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_authors
    ADD CONSTRAINT trusted_authors_pkey PRIMARY KEY (author_url);


--
-- Name: webmention_receipts webmention_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webmention_receipts
    ADD CONSTRAINT webmention_receipts_pkey PRIMARY KEY (id);


--
-- Name: webmention_settings webmention_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webmention_settings
    ADD CONSTRAINT webmention_settings_pkey PRIMARY KEY (id);


--
-- Name: webmentions webmentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webmentions
    ADD CONSTRAINT webmentions_pkey PRIMARY KEY (id);


--
-- Name: work_entries work_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_entries
    ADD CONSTRAINT work_entries_pkey PRIMARY KEY (id);


--
-- Name: work_sessions work_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_pkey PRIMARY KEY (id);


--
-- Name: workouts workouts_google_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workouts
    ADD CONSTRAINT workouts_google_id_key UNIQUE (google_id);


--
-- Name: workouts workouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workouts
    ADD CONSTRAINT workouts_pkey PRIMARY KEY (id);


--
-- Name: agent_session_index_lines_agent_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_index_lines_agent_session_id_index ON public.agent_session_index_lines USING btree (agent_session_id);


--
-- Name: agent_session_index_lines_memory_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_index_lines_memory_file_id_index ON public.agent_session_index_lines USING btree (memory_file_id);


--
-- Name: agent_session_loads_memory_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_loads_memory_file_id_index ON public.agent_session_loads USING btree (memory_file_id);


--
-- Name: agent_session_reads_agent_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_reads_agent_session_id_index ON public.agent_session_reads USING btree (agent_session_id);


--
-- Name: agent_session_reads_memory_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_reads_memory_file_id_index ON public.agent_session_reads USING btree (memory_file_id);


--
-- Name: agent_session_search_hits_agent_session_search_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_search_hits_agent_session_search_id_index ON public.agent_session_search_hits USING btree (agent_session_search_id);


--
-- Name: agent_session_search_hits_memory_fact_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_search_hits_memory_fact_id_index ON public.agent_session_search_hits USING btree (memory_fact_id);


--
-- Name: agent_session_search_hits_memory_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_search_hits_memory_file_id_index ON public.agent_session_search_hits USING btree (memory_file_id);


--
-- Name: agent_session_searches_agent_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_searches_agent_session_id_index ON public.agent_session_searches USING btree (agent_session_id);


--
-- Name: agent_session_tasks_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_session_tasks_task_id_index ON public.agent_session_tasks USING btree (task_id);


--
-- Name: agent_sessions_open_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_sessions_open_index ON public.agent_sessions USING btree (last_seen_at) WHERE (ended_at IS NULL);


--
-- Name: agent_sessions_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_sessions_project_id_index ON public.agent_sessions USING btree (project_id);


--
-- Name: agent_sessions_started_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX agent_sessions_started_at_index ON public.agent_sessions USING btree (started_at);


--
-- Name: analytics_clicks_event_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytics_clicks_event_id_index ON public.analytics_clicks USING btree (event_id);


--
-- Name: analytics_events_address_hash_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytics_events_address_hash_occurred_at_index ON public.analytics_events USING btree (address_hash, occurred_at);


--
-- Name: analytics_events_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytics_events_occurred_at_index ON public.analytics_events USING btree (occurred_at);


--
-- Name: analytics_events_visitor_hash_view_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytics_events_visitor_hash_view_token_index ON public.analytics_events USING btree (visitor_hash, view_token);


--
-- Name: analytics_rollup_clicks_day_path_link_host_link_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_clicks_day_path_link_host_link_path_index ON public.analytics_rollup_clicks USING btree (day, path, link_host, link_path);


--
-- Name: analytics_rollup_clicks_path_day_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytics_rollup_clicks_path_day_index ON public.analytics_rollup_clicks USING btree (path, day);


--
-- Name: analytics_rollup_countries_day_country_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_countries_day_country_code_index ON public.analytics_rollup_countries USING btree (day, country_code) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_devices_day_path_device_class_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_devices_day_path_device_class_index ON public.analytics_rollup_devices USING btree (day, path, device_class) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_hours_day_hour_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_hours_day_hour_index ON public.analytics_rollup_hours USING btree (day, hour);


--
-- Name: analytics_rollup_page_countries_day_path_country_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_page_countries_day_path_country_code_index ON public.analytics_rollup_page_countries USING btree (day, path, country_code) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_page_referrers_day_path_host_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_page_referrers_day_path_host_index ON public.analytics_rollup_page_referrers USING btree (day, path, host) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_paths_day_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_paths_day_path_index ON public.analytics_rollup_paths USING btree (day, path);


--
-- Name: analytics_rollup_reach_month_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_reach_month_path_index ON public.analytics_rollup_reach USING btree (month, path) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_referrers_day_host_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_referrers_day_host_index ON public.analytics_rollup_referrers USING btree (day, host) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_scroll_depths_day_path_scroll_depth_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_scroll_depths_day_path_scroll_depth_index ON public.analytics_rollup_scroll_depths USING btree (day, path, scroll_depth);


--
-- Name: analytics_rollup_sources_day_path_source_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_sources_day_path_source_index ON public.analytics_rollup_sources USING btree (day, path, source) NULLS NOT DISTINCT;


--
-- Name: api_tokens_token_digest_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_tokens_token_digest_index ON public.api_tokens USING btree (token_digest);


--
-- Name: artifact_versions_artifact_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX artifact_versions_artifact_id_number_index ON public.artifact_versions USING btree (artifact_id, number);


--
-- Name: artifact_versions_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artifact_versions_created_at_index ON public.artifact_versions USING btree (created_at);


--
-- Name: artifact_versions_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artifact_versions_session_id_index ON public.artifact_versions USING btree (session_id);


--
-- Name: artifacts_tags_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artifacts_tags_index ON public.artifacts USING gin (tags);


--
-- Name: artifacts_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artifacts_type_index ON public.artifacts USING btree (type);


--
-- Name: attention_snoozes_kind_record_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX attention_snoozes_kind_record_id_index ON public.attention_snoozes USING btree (kind, record_id) NULLS NOT DISTINCT;


--
-- Name: calendar_events_starts_on_ends_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX calendar_events_starts_on_ends_on_index ON public.calendar_events USING btree (starts_on, ends_on);


--
-- Name: commits_commit_date_commit_time_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_commit_date_commit_time_id_index ON public.commits USING btree (commit_date, commit_time, id);


--
-- Name: commits_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_created_at_index ON public.commits USING btree (created_at);


--
-- Name: commits_message_trigram_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_message_trigram_index ON public.commits USING gin (message public.gin_trgm_ops);


--
-- Name: commits_repo_trigram_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_repo_trigram_index ON public.commits USING gin (repo public.gin_trgm_ops);


--
-- Name: commits_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_search_vector_index ON public.commits USING gin (search_vector);


--
-- Name: decision_comments_created_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_comments_created_on_index ON public.decision_comments USING btree ((((created_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: decision_comments_decision_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_comments_decision_id_created_at_index ON public.decision_comments USING btree (decision_id, created_at);


--
-- Name: decision_events_created_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_events_created_on_index ON public.decision_events USING btree ((((created_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: decision_events_decision_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_events_decision_id_created_at_index ON public.decision_events USING btree (decision_id, created_at);


--
-- Name: decision_events_decision_id_option_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_events_decision_id_option_id_index ON public.decision_events USING btree (decision_id, option_id);


--
-- Name: decision_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_tags_tag_id_index ON public.decision_tags USING btree (tag_id);


--
-- Name: decisions_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decisions_search_vector_index ON public.decisions USING gin (search_vector);


--
-- Name: decisions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decisions_status_index ON public.decisions USING btree (status);


--
-- Name: devices_last_signed_in_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX devices_last_signed_in_at_index ON public.devices USING btree (last_signed_in_at);


--
-- Name: held_post_follow_ups_post_id_follow_up_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX held_post_follow_ups_post_id_follow_up_index ON public.held_post_follow_ups USING btree (post_id, follow_up);


--
-- Name: held_webmentions_post_id_source_url_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX held_webmentions_post_id_source_url_index ON public.held_webmentions USING btree (post_id, source_url);


--
-- Name: journal_entries_entry_date_entry_time_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entries_entry_date_entry_time_id_index ON public.journal_entries USING btree (entry_date, entry_time, id);


--
-- Name: journal_entries_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entries_search_vector_index ON public.journal_entries USING gin (search_vector);


--
-- Name: journal_entry_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entry_tags_tag_id_index ON public.journal_entry_tags USING btree (tag_id);


--
-- Name: known_devices_credential_device_place_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX known_devices_credential_device_place_index ON public.known_devices USING btree (api_token_id, oauth_client_id, browser, os, city, country) NULLS NOT DISTINCT;


--
-- Name: known_devices_oauth_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX known_devices_oauth_client_id_index ON public.known_devices USING btree (oauth_client_id);


--
-- Name: link_check_runs_started_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX link_check_runs_started_at_index ON public.link_check_runs USING btree (started_at);


--
-- Name: mail_accounts_address_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mail_accounts_address_index ON public.mail_accounts USING btree (address);


--
-- Name: mail_accounts_provider_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mail_accounts_provider_index ON public.mail_accounts USING btree (provider) WHERE (provider = 'contact_form'::public.mail_provider);


--
-- Name: mail_labels_mail_account_id_gmail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mail_labels_mail_account_id_gmail_id_index ON public.mail_labels USING btree (mail_account_id, gmail_id);


--
-- Name: mail_messages_letter_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_messages_letter_index ON public.mail_messages USING gin ((((((COALESCE((reply_to)::text, ''::text) || ' '::text) || COALESCE((body)::text, ''::text)) || ' '::text) || COALESCE(from_name, ''::text))) public.gin_trgm_ops);


--
-- Name: mail_messages_mail_thread_id_gmail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mail_messages_mail_thread_id_gmail_id_index ON public.mail_messages USING btree (mail_thread_id, gmail_id);


--
-- Name: mail_messages_mail_thread_id_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_messages_mail_thread_id_received_at_index ON public.mail_messages USING btree (mail_thread_id, received_at);


--
-- Name: mail_messages_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_messages_received_at_index ON public.mail_messages USING btree (received_at);


--
-- Name: mail_messages_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_messages_search_vector_index ON public.mail_messages USING gin (search_vector);


--
-- Name: mail_messages_visitor_hash_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_messages_visitor_hash_received_at_index ON public.mail_messages USING btree (visitor_hash, received_at);


--
-- Name: mail_thread_labels_mail_label_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_thread_labels_mail_label_id_index ON public.mail_thread_labels USING btree (mail_label_id);


--
-- Name: mail_thread_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_thread_tags_tag_id_index ON public.mail_thread_tags USING btree (tag_id);


--
-- Name: mail_threads_mail_account_id_gmail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mail_threads_mail_account_id_gmail_id_index ON public.mail_threads USING btree (mail_account_id, gmail_id);


--
-- Name: mail_threads_marked_spam_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_threads_marked_spam_at_index ON public.mail_threads USING btree (marked_spam_at);


--
-- Name: mail_threads_received_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_threads_received_at_id_index ON public.mail_threads USING btree (received_at, id);


--
-- Name: mail_threads_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_threads_status_index ON public.mail_threads USING btree (status);


--
-- Name: mail_threads_waiting_starred_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_threads_waiting_starred_index ON public.mail_threads USING btree (mail_account_id) WHERE ((starred IS TRUE) AND (archived IS FALSE) AND (trashed IS FALSE) AND (draft IS FALSE));


--
-- Name: mail_threads_waiting_unread_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mail_threads_waiting_unread_index ON public.mail_threads USING btree (mail_account_id) WHERE ((status = 'unread'::public.message_status) AND (archived IS FALSE) AND (trashed IS FALSE) AND (draft IS FALSE));


--
-- Name: memory_events_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_events_created_at_index ON public.memory_events USING btree (created_at);


--
-- Name: memory_events_memory_fact_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_events_memory_fact_id_index ON public.memory_events USING btree (memory_fact_id);


--
-- Name: memory_events_memory_file_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_events_memory_file_id_created_at_index ON public.memory_events USING btree (memory_file_id, created_at);


--
-- Name: memory_events_reverted_event_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_events_reverted_event_id_index ON public.memory_events USING btree (reverted_event_id);


--
-- Name: memory_events_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_events_session_id_index ON public.memory_events USING btree (session_id);


--
-- Name: memory_facts_memory_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_facts_memory_file_id_index ON public.memory_facts USING btree (memory_file_id);


--
-- Name: memory_files_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_files_project_id_index ON public.memory_files USING btree (project_id);


--
-- Name: memory_files_scope_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX memory_files_scope_path_index ON public.memory_files USING btree (scope, project_id, task_id, path) NULLS NOT DISTINCT;


--
-- Name: memory_files_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memory_files_task_id_index ON public.memory_files USING btree (task_id);


--
-- Name: note_folders_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_folders_parent_id_index ON public.note_folders USING btree (parent_id);


--
-- Name: note_links_target_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_links_target_index ON public.note_links USING btree (lower((title)::text));


--
-- Name: note_links_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX note_links_title_index ON public.note_links USING btree (note_id, lower((title)::text));


--
-- Name: note_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_tags_tag_id_index ON public.note_tags USING btree (tag_id);


--
-- Name: notes_folder_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_folder_id_index ON public.notes USING btree (folder_id);


--
-- Name: notes_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_search_vector_index ON public.notes USING gin (search_vector);


--
-- Name: notes_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX notes_title_index ON public.notes USING btree (lower((title)::text));


--
-- Name: oauth_clients_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oauth_clients_client_id_index ON public.oauth_clients USING btree (client_id);


--
-- Name: oauth_clients_visitor_hash_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_clients_visitor_hash_created_at_index ON public.oauth_clients USING btree (visitor_hash, created_at);


--
-- Name: oauth_codes_code_digest_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oauth_codes_code_digest_index ON public.oauth_codes USING btree (code_digest);


--
-- Name: oauth_codes_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_codes_expires_at_index ON public.oauth_codes USING btree (expires_at);


--
-- Name: oauth_codes_oauth_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_codes_oauth_client_id_index ON public.oauth_codes USING btree (oauth_client_id);


--
-- Name: oauth_tokens_access_token_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_tokens_access_token_id_index ON public.oauth_tokens USING btree (access_token_id);


--
-- Name: oauth_tokens_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_tokens_expires_at_index ON public.oauth_tokens USING btree (expires_at);


--
-- Name: oauth_tokens_oauth_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth_tokens_oauth_client_id_index ON public.oauth_tokens USING btree (oauth_client_id);


--
-- Name: oauth_tokens_token_digest_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oauth_tokens_token_digest_index ON public.oauth_tokens USING btree (token_digest);


--
-- Name: owner_identities_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX owner_identities_email_index ON public.owner_identities USING btree (email);


--
-- Name: people_google_connection_id_google_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX people_google_connection_id_google_id_index ON public.people USING btree (google_connection_id, google_id);


--
-- Name: people_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX people_key_index ON public.people USING btree (key);


--
-- Name: people_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX people_search_vector_index ON public.people USING gin (search_vector);


--
-- Name: performance_jobs_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX performance_jobs_occurred_at_index ON public.performance_jobs USING btree (occurred_at);


--
-- Name: performance_jobs_schedule_key_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX performance_jobs_schedule_key_occurred_at_index ON public.performance_jobs USING btree (schedule_key, occurred_at);


--
-- Name: performance_pages_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX performance_pages_occurred_at_index ON public.performance_pages USING btree (occurred_at);


--
-- Name: performance_requests_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX performance_requests_occurred_at_index ON public.performance_requests USING btree (occurred_at);


--
-- Name: performance_requests_route_verb_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX performance_requests_route_verb_occurred_at_index ON public.performance_requests USING btree (route, verb, occurred_at);


--
-- Name: performance_rollup_jobs_day_job_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX performance_rollup_jobs_day_job_index ON public.performance_rollup_jobs USING btree (day, job);


--
-- Name: performance_rollup_pages_day_route_metric_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX performance_rollup_pages_day_route_metric_index ON public.performance_rollup_pages USING btree (day, route, metric);


--
-- Name: performance_rollup_requests_day_verb_route_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX performance_rollup_requests_day_verb_route_index ON public.performance_rollup_requests USING btree (day, verb, route) NULLS NOT DISTINCT;


--
-- Name: photo_claims_photo_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX photo_claims_photo_id_index ON public.photo_claims USING btree (photo_id);


--
-- Name: photos_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX photos_created_at_index ON public.photos USING btree (created_at);


--
-- Name: photos_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX photos_key_index ON public.photos USING btree (key);


--
-- Name: post_edits_post_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_edits_post_id_created_at_index ON public.post_edits USING btree (post_id, created_at);


--
-- Name: post_link_checks_post_id_url_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX post_link_checks_post_id_url_index ON public.post_link_checks USING btree (post_id, url);


--
-- Name: post_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_tags_tag_id_index ON public.post_tags USING btree (tag_id);


--
-- Name: posts_published_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_published_at_index ON public.posts USING btree (published_at);


--
-- Name: posts_published_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_published_on_index ON public.posts USING btree ((((published_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: posts_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_search_vector_index ON public.posts USING gin (search_vector);


--
-- Name: posts_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_status_index ON public.posts USING btree (status);


--
-- Name: project_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_tags_tag_id_index ON public.project_tags USING btree (tag_id);


--
-- Name: projects_archived_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_archived_on_index ON public.projects USING btree (archived_on);


--
-- Name: projects_created_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_created_on_index ON public.projects USING btree ((((created_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: projects_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_key_index ON public.projects USING btree (lower((key)::text));


--
-- Name: projects_repo_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_repo_index ON public.projects USING btree (repo);


--
-- Name: projects_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_search_vector_index ON public.projects USING gin (search_vector);


--
-- Name: pull_requests_finished_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pull_requests_finished_on_index ON public.pull_requests USING btree ((((COALESCE(merged_at, closed_at) AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: pull_requests_ready_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pull_requests_ready_on_index ON public.pull_requests USING btree ((((ready_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: pull_requests_repo_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pull_requests_repo_number_index ON public.pull_requests USING btree (repo, number);


--
-- Name: pull_requests_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pull_requests_search_vector_index ON public.pull_requests USING gin (search_vector);


--
-- Name: record_links_one_source_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX record_links_one_source_key ON public.record_links USING btree (right_kind, right_id) WHERE (relation = 'sourced_from'::public.record_link_relation);


--
-- Name: record_links_pair_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX record_links_pair_key ON public.record_links USING btree (left_kind, left_id, right_kind, right_id);


--
-- Name: record_links_right_kind_right_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX record_links_right_kind_right_id_index ON public.record_links USING btree (right_kind, right_id);


--
-- Name: review_notes_period_starts_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX review_notes_period_starts_on_index ON public.review_notes USING btree (period, starts_on);


--
-- Name: saved_views_screen_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_views_screen_name_index ON public.saved_views USING btree (screen, name);


--
-- Name: search_attempts_attempted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_attempts_attempted_at_index ON public.search_attempts USING btree (attempted_at);


--
-- Name: search_attempts_visitor_hash_attempted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_attempts_visitor_hash_attempted_at_index ON public.search_attempts USING btree (visitor_hash, attempted_at);


--
-- Name: service_apps_provider_host_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX service_apps_provider_host_index ON public.service_apps USING btree (provider, host);


--
-- Name: service_connections_provider_host_account_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX service_connections_provider_host_account_id_index ON public.service_connections USING btree (provider, host, account_id) NULLS NOT DISTINCT;


--
-- Name: service_connections_saves_contacts_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX service_connections_saves_contacts_index ON public.service_connections USING btree (saves_contacts) WHERE saves_contacts;


--
-- Name: share_group_files_share_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX share_group_files_share_group_id_index ON public.share_group_files USING btree (share_group_id);


--
-- Name: sightings_credential_device_product_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sightings_credential_device_product_index ON public.sightings USING btree (api_token_id, oauth_client_id, browser, os, product) NULLS NOT DISTINCT;


--
-- Name: sightings_oauth_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sightings_oauth_client_id_index ON public.sightings USING btree (oauth_client_id);


--
-- Name: sign_ins_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sign_ins_created_at_index ON public.sign_ins USING btree (created_at);


--
-- Name: sign_ins_device_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sign_ins_device_id_index ON public.sign_ins USING btree (device_id);


--
-- Name: sign_ins_visitor_hash_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sign_ins_visitor_hash_created_at_index ON public.sign_ins USING btree (visitor_hash, created_at);


--
-- Name: social_post_deliveries_connection_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_post_deliveries_connection_id_index ON public.social_post_deliveries USING btree (connection_id);


--
-- Name: social_post_deliveries_social_post_id_connection_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_deliveries_social_post_id_connection_id_index ON public.social_post_deliveries USING btree (social_post_id, connection_id);


--
-- Name: social_post_parts_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_post_parts_search_vector_index ON public.social_post_parts USING gin (search_vector);


--
-- Name: social_post_parts_social_post_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_parts_social_post_id_position_index ON public.social_post_parts USING btree (social_post_id, "position");


--
-- Name: social_post_photos_photo_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_post_photos_photo_key_index ON public.social_post_photos USING btree (photo_key);


--
-- Name: social_post_photos_social_post_part_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_photos_social_post_part_id_position_index ON public.social_post_photos USING btree (social_post_part_id, "position");


--
-- Name: social_posts_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_posts_post_id_index ON public.social_posts USING btree (post_id);


--
-- Name: social_posts_posted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_posts_posted_at_index ON public.social_posts USING btree (posted_at);


--
-- Name: social_posts_posted_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_posts_posted_on_index ON public.social_posts USING btree ((((posted_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: social_posts_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_posts_status_index ON public.social_posts USING btree (status);


--
-- Name: sprints_sprint_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sprints_sprint_date_index ON public.sprints USING btree (sprint_date);


--
-- Name: suggestion_edits_suggestion_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX suggestion_edits_suggestion_id_position_index ON public.suggestion_edits USING btree (suggestion_id, "position");


--
-- Name: suggestion_edits_suggestion_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggestion_edits_suggestion_id_status_index ON public.suggestion_edits USING btree (suggestion_id, status);


--
-- Name: suggestions_created_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggestions_created_on_index ON public.suggestions USING btree ((((created_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: suggestions_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggestions_post_id_index ON public.suggestions USING btree (post_id);


--
-- Name: suggestions_social_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggestions_social_post_id_index ON public.suggestions USING btree (social_post_id);


--
-- Name: sync_states_kind_sync_repo_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sync_states_kind_sync_repo_index ON public.sync_states USING btree (kind, sync, repo) NULLS NOT DISTINCT;


--
-- Name: task_comments_created_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_comments_created_on_index ON public.task_comments USING btree ((((created_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: task_comments_provider_remote_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_comments_provider_remote_id_index ON public.task_comments USING btree (provider, remote_id);


--
-- Name: task_comments_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_comments_task_id_index ON public.task_comments USING btree (task_id);


--
-- Name: task_contributors_task_id_agent_model_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_contributors_task_id_agent_model_index ON public.task_contributors USING btree (task_id, agent, model) NULLS NOT DISTINCT;


--
-- Name: task_events_moved_from_sprint_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_moved_from_sprint_on_index ON public.task_events USING btree (from_sprint_on) WHERE (kind = 'moved'::public.task_event_kind);


--
-- Name: task_events_task_id_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_task_id_occurred_at_index ON public.task_events USING btree (task_id, occurred_at);


--
-- Name: task_links_from_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_links_from_task_id_index ON public.task_links USING btree (from_task_id);


--
-- Name: task_links_one_parent_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_links_one_parent_key ON public.task_links USING btree (to_task_id) WHERE (type = 'parent'::public.task_link_type);


--
-- Name: task_links_pair_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_links_pair_key ON public.task_links USING btree (LEAST(from_task_id, to_task_id), GREATEST(from_task_id, to_task_id));


--
-- Name: task_links_to_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_links_to_task_id_index ON public.task_links USING btree (to_task_id);


--
-- Name: task_number_counters_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_number_counters_project_id_index ON public.task_number_counters USING btree (project_id) NULLS NOT DISTINCT;


--
-- Name: task_rule_projects_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_rule_projects_project_id_index ON public.task_rule_projects USING btree (project_id);


--
-- Name: task_rule_projects_task_rule_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_rule_projects_task_rule_id_key ON public.task_rule_projects USING btree (task_rule_id);


--
-- Name: task_rule_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_rule_tags_tag_id_index ON public.task_rule_tags USING btree (tag_id);


--
-- Name: task_rules_provider_pattern_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_rules_provider_pattern_index ON public.task_rules USING btree (provider, pattern);


--
-- Name: task_sources_provider_remote_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_sources_provider_remote_id_index ON public.task_sources USING btree (provider, remote_id);


--
-- Name: task_sources_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_sources_task_id_index ON public.task_sources USING btree (task_id);


--
-- Name: task_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_tags_tag_id_index ON public.task_tags USING btree (tag_id);


--
-- Name: tasks_completed_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_completed_at_index ON public.tasks USING btree (completed_at);


--
-- Name: tasks_completed_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_completed_on_index ON public.tasks USING btree ((((completed_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: tasks_list_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_list_position_index ON public.tasks USING btree (list, "position");


--
-- Name: tasks_newest_first_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_newest_first_index ON public.tasks USING btree (COALESCE(completed_at, created_at), id);


--
-- Name: tasks_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_project_id_index ON public.tasks USING btree (project_id);


--
-- Name: tasks_project_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tasks_project_id_number_index ON public.tasks USING btree (project_id, number) NULLS NOT DISTINCT;


--
-- Name: tasks_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_search_vector_index ON public.tasks USING gin (search_vector);


--
-- Name: tasks_series_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_series_id_index ON public.tasks USING btree (series_id);


--
-- Name: tasks_sprint_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_sprint_id_position_index ON public.tasks USING btree (sprint_id, "position");


--
-- Name: tasks_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_status_index ON public.tasks USING btree (status);


--
-- Name: webmention_receipts_post_id_source_url_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX webmention_receipts_post_id_source_url_index ON public.webmention_receipts USING btree (post_id, source_url);


--
-- Name: webmention_receipts_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmention_receipts_received_at_index ON public.webmention_receipts USING btree (received_at);


--
-- Name: webmention_receipts_visitor_hash_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmention_receipts_visitor_hash_received_at_index ON public.webmention_receipts USING btree (visitor_hash, received_at);


--
-- Name: webmentions_author_url_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_author_url_index ON public.webmentions USING btree (author_url);


--
-- Name: webmentions_post_id_source_url_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX webmentions_post_id_source_url_index ON public.webmentions USING btree (post_id, source_url);


--
-- Name: webmentions_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_received_at_index ON public.webmentions USING btree (received_at);


--
-- Name: webmentions_received_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_received_on_index ON public.webmentions USING btree ((((received_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: webmentions_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_search_vector_index ON public.webmentions USING gin (search_vector);


--
-- Name: webmentions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_status_index ON public.webmentions USING btree (status);


--
-- Name: work_entries_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_entries_position_index ON public.work_entries USING btree ("position");


--
-- Name: work_entries_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_entries_search_vector_index ON public.work_entries USING gin (search_vector);


--
-- Name: work_sessions_one_open_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX work_sessions_one_open_index ON public.work_sessions USING btree (task_id) WHERE (ended_at IS NULL);


--
-- Name: work_sessions_started_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_sessions_started_on_index ON public.work_sessions USING btree ((((started_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: work_sessions_task_id_started_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_sessions_task_id_started_at_index ON public.work_sessions USING btree (task_id, started_at);


--
-- Name: workouts_started_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workouts_started_at_index ON public.workouts USING btree (started_at);


--
-- Name: workouts_started_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workouts_started_on_index ON public.workouts USING btree ((((started_at AT TIME ZONE 'America/Chicago'::text))::date));


--
-- Name: agent_session_index_lines agent_session_index_lines_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agent_session_index_lines_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.agent_session_index_lines FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: agent_session_reads agent_session_reads_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agent_session_reads_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.agent_session_reads FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: agent_session_search_hits agent_session_search_hits_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agent_session_search_hits_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.agent_session_search_hits FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: agent_session_searches agent_session_searches_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agent_session_searches_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.agent_session_searches FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: agent_sessions agent_sessions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agent_sessions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.agent_sessions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_clicks analytics_rollup_clicks_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_clicks_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_clicks FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_countries analytics_rollup_countries_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_countries_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_countries FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_devices analytics_rollup_devices_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_devices_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_devices FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_hours analytics_rollup_hours_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_hours_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_hours FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_page_countries analytics_rollup_page_countries_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_page_countries_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_page_countries FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_page_referrers analytics_rollup_page_referrers_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_page_referrers_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_page_referrers FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_paths analytics_rollup_paths_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_paths_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_paths FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_reach analytics_rollup_reach_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_reach_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_reach FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_referrers analytics_rollup_referrers_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_referrers_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_referrers FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_scroll_depths analytics_rollup_scroll_depths_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_scroll_depths_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_scroll_depths FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollup_sources analytics_rollup_sources_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollup_sources_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollup_sources FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: analytics_rollups analytics_rollups_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER analytics_rollups_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.analytics_rollups FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: artifact_versions artifact_versions_next_number; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artifact_versions_next_number BEFORE INSERT ON public.artifact_versions FOR EACH ROW EXECUTE FUNCTION public.artifact_versions_next_number();


--
-- Name: artifact_versions artifact_versions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artifact_versions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.artifact_versions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: artifacts artifacts_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artifacts_drop_record_links AFTER DELETE ON public.artifacts FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('artifact');


--
-- Name: artifacts artifacts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artifacts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.artifacts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: attention_snoozes attention_snoozes_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER attention_snoozes_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.attention_snoozes FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: calendar_events calendar_events_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER calendar_events_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: calendars calendars_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER calendars_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.calendars FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: commits commits_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER commits_drop_record_links AFTER DELETE ON public.commits FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('commit');


--
-- Name: commits commits_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER commits_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.commits FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: decision_comments decision_comments_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decision_comments_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.decision_comments FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: decision_events decision_events_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decision_events_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.decision_events FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: decision_options decision_options_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decision_options_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.decision_options FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: decision_tags decision_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decision_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.decision_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: decisions decisions_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decisions_drop_record_links AFTER DELETE ON public.decisions FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('decision');


--
-- Name: decisions decisions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER decisions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.decisions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: devices devices_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER devices_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.devices FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: health_days health_days_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_days_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.health_days FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: journal_entries journal_entries_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER journal_entries_drop_record_links AFTER DELETE ON public.journal_entries FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('journal_entry');


--
-- Name: journal_entries journal_entries_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER journal_entries_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.journal_entries FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: journal_entry_tags journal_entry_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER journal_entry_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.journal_entry_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: known_devices known_devices_drop_attention_snoozes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER known_devices_drop_attention_snoozes AFTER DELETE ON public.known_devices FOR EACH ROW EXECUTE FUNCTION public.attention_snoozes_drop_record('new_device');


--
-- Name: link_check_runs link_check_runs_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER link_check_runs_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.link_check_runs FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_accounts mail_accounts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_accounts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_accounts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_labels mail_labels_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_labels_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_labels FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_messages mail_messages_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_messages_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_messages FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_settings mail_settings_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_settings_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_settings FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_thread_labels mail_thread_labels_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_thread_labels_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_thread_labels FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_thread_tags mail_thread_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_thread_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_thread_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: mail_threads mail_threads_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_threads_drop_record_links AFTER DELETE ON public.mail_threads FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('mail_thread');


--
-- Name: mail_threads mail_threads_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mail_threads_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.mail_threads FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: memory_events memory_events_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER memory_events_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.memory_events FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: memory_facts memory_facts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER memory_facts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.memory_facts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: memory_files memory_files_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER memory_files_drop_record_links AFTER DELETE ON public.memory_files FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('memory_file');


--
-- Name: memory_files memory_files_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER memory_files_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.memory_files FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: note_folders note_folders_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER note_folders_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.note_folders FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: note_folders note_folders_refuse_loop; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER note_folders_refuse_loop BEFORE INSERT OR UPDATE OF parent_id ON public.note_folders FOR EACH ROW WHEN ((new.parent_id IS NOT NULL)) EXECUTE FUNCTION public.note_folders_refuse_loop();


--
-- Name: note_tags note_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER note_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.note_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: notes notes_next_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notes_next_version BEFORE UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION public.notes_next_version();


--
-- Name: notes notes_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notes_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: oauth_clients oauth_clients_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER oauth_clients_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.oauth_clients FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: oauth_tokens oauth_tokens_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER oauth_tokens_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.oauth_tokens FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: people people_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER people_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.people FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: photos photos_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER photos_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.photos FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: post_edits post_edits_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_edits_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.post_edits FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: post_link_checks post_link_checks_drop_attention_snoozes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_link_checks_drop_attention_snoozes AFTER DELETE ON public.post_link_checks FOR EACH ROW EXECUTE FUNCTION public.attention_snoozes_drop_record('broken_link');


--
-- Name: post_link_checks post_link_checks_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_link_checks_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.post_link_checks FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: post_tags post_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.post_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: post_tags post_tags_record_removal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_tags_record_removal AFTER DELETE ON public.post_tags FOR EACH ROW EXECUTE FUNCTION public.post_tags_record_removal();


--
-- Name: posts posts_default_webmentions_enabled; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_default_webmentions_enabled BEFORE INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_default_webmentions_enabled();


--
-- Name: posts posts_drop_attention_snoozes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_drop_attention_snoozes AFTER DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.attention_snoozes_drop_record('draft');


--
-- Name: posts posts_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_drop_record_links AFTER DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('post');


--
-- Name: posts posts_lock_published_slug; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_lock_published_slug BEFORE UPDATE OF slug ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_lock_published_slug();


--
-- Name: posts posts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: posts posts_record_deletion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_record_deletion AFTER DELETE ON public.posts FOR EACH ROW WHEN ((old.status = 'published'::public.post_status)) EXECUTE FUNCTION public.posts_record_deletion();


--
-- Name: project_tags project_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER project_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.project_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: projects projects_default_key; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_default_key BEFORE INSERT OR UPDATE ON public.projects FOR EACH ROW WHEN ((new.key IS NULL)) EXECUTE FUNCTION public.projects_default_key();


--
-- Name: projects projects_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_drop_record_links AFTER DELETE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('project');


--
-- Name: projects projects_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: pull_requests pull_requests_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pull_requests_drop_record_links AFTER DELETE ON public.pull_requests FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('pull_request');


--
-- Name: pull_requests pull_requests_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pull_requests_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.pull_requests FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: record_links record_links_find_records; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER record_links_find_records BEFORE INSERT OR UPDATE OF left_kind, left_id, right_kind, right_id ON public.record_links FOR EACH ROW EXECUTE FUNCTION public.record_links_find_records();


--
-- Name: record_links record_links_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER record_links_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.record_links FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: review_notes review_notes_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER review_notes_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.review_notes FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: saved_views saved_views_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER saved_views_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.saved_views FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: service_apps service_apps_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_apps_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.service_apps FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: service_connections service_connections_drop_attention_snoozes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_connections_drop_attention_snoozes AFTER DELETE ON public.service_connections FOR EACH ROW EXECUTE FUNCTION public.attention_snoozes_drop_record('lapsing');


--
-- Name: service_connections service_connections_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_connections_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.service_connections FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: share_group_files share_group_files_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER share_group_files_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.share_group_files FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: share_groups share_groups_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER share_groups_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.share_groups FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: short_codes short_codes_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER short_codes_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.short_codes FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: short_link_checks short_link_checks_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER short_link_checks_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.short_link_checks FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: short_links short_links_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER short_links_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.short_links FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: sign_ins sign_ins_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sign_ins_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.sign_ins FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: social_post_deliveries social_post_deliveries_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER social_post_deliveries_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.social_post_deliveries FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: social_post_parts social_post_parts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER social_post_parts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.social_post_parts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: social_posts social_posts_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER social_posts_drop_record_links AFTER DELETE ON public.social_posts FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('social_post');


--
-- Name: social_posts social_posts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER social_posts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.social_posts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: sprints sprints_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sprints_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.sprints FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: suggestion_edits suggestion_edits_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suggestion_edits_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.suggestion_edits FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: suggestions suggestions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suggestions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.suggestions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: sync_states sync_states_delete_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_states_delete_notify_admin_change AFTER DELETE ON public.sync_states FOR EACH ROW WHEN ((old.kind = 'failure'::public.sync_state_kind)) EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: sync_states sync_states_insert_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_states_insert_notify_admin_change AFTER INSERT ON public.sync_states FOR EACH ROW WHEN ((new.kind = 'failure'::public.sync_state_kind)) EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: sync_states sync_states_update_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_states_update_notify_admin_change AFTER UPDATE ON public.sync_states FOR EACH ROW WHEN (((old.kind = 'failure'::public.sync_state_kind) OR (new.kind = 'failure'::public.sync_state_kind))) EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: tags tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_comments task_comments_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_comments_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_comments FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_contributors task_contributors_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_contributors_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_contributors FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_events task_events_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_events_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_events FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_links task_links_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_links_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_links FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_rule_projects task_rule_projects_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_rule_projects_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_rule_projects FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_rule_tags task_rule_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_rule_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_rule_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: projects task_rules_last_target; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_rules_last_target BEFORE DELETE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.task_rules_last_target();


--
-- Name: tags task_rules_last_target; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_rules_last_target BEFORE DELETE ON public.tags FOR EACH ROW EXECUTE FUNCTION public.task_rules_last_target();


--
-- Name: task_rules task_rules_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_rules_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_rules FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_series task_series_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_series_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_series FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_sources task_sources_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_sources_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_sources FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: task_tags task_tags_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_tags_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.task_tags FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: tasks tasks_drop_attention_snoozes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_drop_attention_snoozes AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.attention_snoozes_drop_record('carried', 'someday');


--
-- Name: tasks tasks_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_drop_record_links AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('task');


--
-- Name: tasks tasks_next_number; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_next_number BEFORE INSERT ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_next_number();


--
-- Name: tasks tasks_next_number_on_move; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_next_number_on_move BEFORE UPDATE OF project_id ON public.tasks FOR EACH ROW WHEN ((old.project_id IS DISTINCT FROM new.project_id)) EXECUTE FUNCTION public.tasks_next_number();


--
-- Name: tasks tasks_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: trusted_authors trusted_authors_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trusted_authors_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.trusted_authors FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: webmention_settings webmention_settings_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER webmention_settings_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.webmention_settings FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: webmentions webmentions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER webmentions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.webmentions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: work_entries work_entries_drop_record_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER work_entries_drop_record_links AFTER DELETE ON public.work_entries FOR EACH ROW EXECUTE FUNCTION public.record_links_drop_record('work_entry');


--
-- Name: work_entries work_entries_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER work_entries_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.work_entries FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: work_sessions work_sessions_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER work_sessions_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.work_sessions FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: workouts workouts_notify_admin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER workouts_notify_admin_change AFTER INSERT OR DELETE OR UPDATE ON public.workouts FOR EACH ROW EXECUTE FUNCTION public.notify_admin_change();


--
-- Name: agent_session_index_lines agent_session_index_lines_agent_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_index_lines
    ADD CONSTRAINT agent_session_index_lines_agent_session_id_fkey FOREIGN KEY (agent_session_id) REFERENCES public.agent_sessions(id) ON DELETE CASCADE;


--
-- Name: agent_session_index_lines agent_session_index_lines_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_index_lines
    ADD CONSTRAINT agent_session_index_lines_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE SET NULL;


--
-- Name: agent_session_loads agent_session_loads_agent_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_loads
    ADD CONSTRAINT agent_session_loads_agent_session_id_fkey FOREIGN KEY (agent_session_id) REFERENCES public.agent_sessions(id) ON DELETE CASCADE;


--
-- Name: agent_session_loads agent_session_loads_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_loads
    ADD CONSTRAINT agent_session_loads_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE CASCADE;


--
-- Name: agent_session_reads agent_session_reads_agent_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_reads
    ADD CONSTRAINT agent_session_reads_agent_session_id_fkey FOREIGN KEY (agent_session_id) REFERENCES public.agent_sessions(id) ON DELETE CASCADE;


--
-- Name: agent_session_reads agent_session_reads_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_reads
    ADD CONSTRAINT agent_session_reads_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE SET NULL;


--
-- Name: agent_session_search_hits agent_session_search_hits_agent_session_search_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_search_hits
    ADD CONSTRAINT agent_session_search_hits_agent_session_search_id_fkey FOREIGN KEY (agent_session_search_id) REFERENCES public.agent_session_searches(id) ON DELETE CASCADE;


--
-- Name: agent_session_search_hits agent_session_search_hits_memory_fact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_search_hits
    ADD CONSTRAINT agent_session_search_hits_memory_fact_id_fkey FOREIGN KEY (memory_fact_id) REFERENCES public.memory_facts(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: agent_session_search_hits agent_session_search_hits_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_search_hits
    ADD CONSTRAINT agent_session_search_hits_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE SET NULL;


--
-- Name: agent_session_searches agent_session_searches_agent_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_searches
    ADD CONSTRAINT agent_session_searches_agent_session_id_fkey FOREIGN KEY (agent_session_id) REFERENCES public.agent_sessions(id) ON DELETE CASCADE;


--
-- Name: agent_session_tasks agent_session_tasks_agent_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_tasks
    ADD CONSTRAINT agent_session_tasks_agent_session_id_fkey FOREIGN KEY (agent_session_id) REFERENCES public.agent_sessions(id) ON DELETE CASCADE;


--
-- Name: agent_session_tasks agent_session_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_session_tasks
    ADD CONSTRAINT agent_session_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: agent_sessions agent_sessions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_sessions
    ADD CONSTRAINT agent_sessions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: analytics_clicks analytics_clicks_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_clicks
    ADD CONSTRAINT analytics_clicks_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.analytics_events(id) ON DELETE CASCADE;


--
-- Name: analytics_rollup_clicks analytics_rollup_clicks_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_clicks
    ADD CONSTRAINT analytics_rollup_clicks_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_countries analytics_rollup_countries_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_countries
    ADD CONSTRAINT analytics_rollup_countries_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_devices analytics_rollup_devices_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_devices
    ADD CONSTRAINT analytics_rollup_devices_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_hours analytics_rollup_hours_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_hours
    ADD CONSTRAINT analytics_rollup_hours_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_page_countries analytics_rollup_page_countries_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_page_countries
    ADD CONSTRAINT analytics_rollup_page_countries_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_page_referrers analytics_rollup_page_referrers_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_page_referrers
    ADD CONSTRAINT analytics_rollup_page_referrers_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_paths analytics_rollup_paths_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_paths
    ADD CONSTRAINT analytics_rollup_paths_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_referrers analytics_rollup_referrers_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_referrers
    ADD CONSTRAINT analytics_rollup_referrers_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_scroll_depths analytics_rollup_scroll_depths_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_scroll_depths
    ADD CONSTRAINT analytics_rollup_scroll_depths_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: analytics_rollup_sources analytics_rollup_sources_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_sources
    ADD CONSTRAINT analytics_rollup_sources_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


--
-- Name: artifact_versions artifact_versions_artifact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_versions
    ADD CONSTRAINT artifact_versions_artifact_id_fkey FOREIGN KEY (artifact_id) REFERENCES public.artifacts(id) ON DELETE CASCADE;


--
-- Name: artifact_versions artifact_versions_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_versions
    ADD CONSTRAINT artifact_versions_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.agent_sessions(id) ON DELETE SET NULL;


--
-- Name: calendar_events calendar_events_calendar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_calendar_id_fkey FOREIGN KEY (calendar_id) REFERENCES public.calendars(id) ON DELETE CASCADE;


--
-- Name: contact_syncs contact_syncs_google_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_syncs
    ADD CONSTRAINT contact_syncs_google_connection_id_fkey FOREIGN KEY (google_connection_id) REFERENCES public.service_connections(id) ON DELETE CASCADE;


--
-- Name: decision_comments decision_comments_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_comments
    ADD CONSTRAINT decision_comments_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(id) ON DELETE CASCADE;


--
-- Name: decision_events decision_events_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT decision_events_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(id) ON DELETE CASCADE;


--
-- Name: decision_events decision_events_option_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT decision_events_option_fkey FOREIGN KEY (decision_id, option_id) REFERENCES public.decision_options(decision_id, id) ON DELETE CASCADE;


--
-- Name: decision_options decision_options_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT decision_options_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(id) ON DELETE CASCADE;


--
-- Name: decision_tags decision_tags_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_tags
    ADD CONSTRAINT decision_tags_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(id) ON DELETE CASCADE;


--
-- Name: decision_tags decision_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_tags
    ADD CONSTRAINT decision_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: decisions decisions_resolved_option_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_resolved_option_fkey FOREIGN KEY (id, resolved_option_id) REFERENCES public.decision_options(decision_id, id);


--
-- Name: held_post_follow_ups held_post_follow_ups_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_post_follow_ups
    ADD CONSTRAINT held_post_follow_ups_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: held_title_fetches held_title_fetches_short_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_title_fetches
    ADD CONSTRAINT held_title_fetches_short_link_id_fkey FOREIGN KEY (short_link_id) REFERENCES public.short_links(id) ON DELETE CASCADE;


--
-- Name: held_webmentions held_webmentions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_webmentions
    ADD CONSTRAINT held_webmentions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: journal_entry_tags journal_entry_tags_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_tags
    ADD CONSTRAINT journal_entry_tags_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id) ON DELETE CASCADE;


--
-- Name: journal_entry_tags journal_entry_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_tags
    ADD CONSTRAINT journal_entry_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: known_devices known_devices_api_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.known_devices
    ADD CONSTRAINT known_devices_api_token_id_fkey FOREIGN KEY (api_token_id) REFERENCES public.api_tokens(id) ON DELETE CASCADE;


--
-- Name: known_devices known_devices_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.known_devices
    ADD CONSTRAINT known_devices_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: mail_attachments mail_attachments_mail_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_attachments
    ADD CONSTRAINT mail_attachments_mail_message_id_fkey FOREIGN KEY (mail_message_id) REFERENCES public.mail_messages(id) ON DELETE CASCADE;


--
-- Name: mail_labels mail_labels_mail_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_labels
    ADD CONSTRAINT mail_labels_mail_account_id_fkey FOREIGN KEY (mail_account_id) REFERENCES public.mail_accounts(id) ON DELETE CASCADE;


--
-- Name: mail_messages mail_messages_mail_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_messages
    ADD CONSTRAINT mail_messages_mail_thread_id_fkey FOREIGN KEY (mail_thread_id) REFERENCES public.mail_threads(id) ON DELETE CASCADE;


--
-- Name: mail_thread_labels mail_thread_labels_mail_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_labels
    ADD CONSTRAINT mail_thread_labels_mail_label_id_fkey FOREIGN KEY (mail_label_id) REFERENCES public.mail_labels(id) ON DELETE CASCADE;


--
-- Name: mail_thread_labels mail_thread_labels_mail_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_labels
    ADD CONSTRAINT mail_thread_labels_mail_thread_id_fkey FOREIGN KEY (mail_thread_id) REFERENCES public.mail_threads(id) ON DELETE CASCADE;


--
-- Name: mail_thread_tags mail_thread_tags_mail_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_tags
    ADD CONSTRAINT mail_thread_tags_mail_thread_id_fkey FOREIGN KEY (mail_thread_id) REFERENCES public.mail_threads(id) ON DELETE CASCADE;


--
-- Name: mail_thread_tags mail_thread_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_thread_tags
    ADD CONSTRAINT mail_thread_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: mail_threads mail_threads_mail_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_threads
    ADD CONSTRAINT mail_threads_mail_account_id_fkey FOREIGN KEY (mail_account_id) REFERENCES public.mail_accounts(id) ON DELETE CASCADE;


--
-- Name: memory_events memory_events_memory_fact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_events
    ADD CONSTRAINT memory_events_memory_fact_id_fkey FOREIGN KEY (memory_fact_id) REFERENCES public.memory_facts(id) ON DELETE CASCADE;


--
-- Name: memory_events memory_events_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_events
    ADD CONSTRAINT memory_events_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE CASCADE;


--
-- Name: memory_events memory_events_reverted_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_events
    ADD CONSTRAINT memory_events_reverted_event_id_fkey FOREIGN KEY (reverted_event_id) REFERENCES public.memory_events(id) ON DELETE CASCADE;


--
-- Name: memory_events memory_events_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_events
    ADD CONSTRAINT memory_events_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.agent_sessions(id) ON DELETE SET NULL;


--
-- Name: memory_facts memory_facts_memory_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_facts
    ADD CONSTRAINT memory_facts_memory_file_id_fkey FOREIGN KEY (memory_file_id) REFERENCES public.memory_files(id) ON DELETE CASCADE;


--
-- Name: memory_files memory_files_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_files
    ADD CONSTRAINT memory_files_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: memory_files memory_files_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_files
    ADD CONSTRAINT memory_files_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: note_folders note_folders_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_folders
    ADD CONSTRAINT note_folders_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.note_folders(id) ON DELETE RESTRICT;


--
-- Name: note_links note_links_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_links
    ADD CONSTRAINT note_links_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: note_tags note_tags_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_tags
    ADD CONSTRAINT note_tags_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: note_tags note_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_tags
    ADD CONSTRAINT note_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: notes notes_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.note_folders(id) ON DELETE RESTRICT;


--
-- Name: oauth_codes oauth_codes_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_tokens oauth_tokens_access_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_access_token_id_fkey FOREIGN KEY (access_token_id) REFERENCES public.oauth_tokens(id) ON DELETE SET NULL;


--
-- Name: oauth_tokens oauth_tokens_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: people people_google_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_google_connection_id_fkey FOREIGN KEY (google_connection_id) REFERENCES public.service_connections(id) ON DELETE SET NULL;


--
-- Name: performance_rollup_jobs performance_rollup_jobs_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_jobs
    ADD CONSTRAINT performance_rollup_jobs_day_fkey FOREIGN KEY (day) REFERENCES public.performance_rollups(day) ON DELETE CASCADE;


--
-- Name: performance_rollup_pages performance_rollup_pages_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_pages
    ADD CONSTRAINT performance_rollup_pages_day_fkey FOREIGN KEY (day) REFERENCES public.performance_rollups(day) ON DELETE CASCADE;


--
-- Name: performance_rollup_requests performance_rollup_requests_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.performance_rollup_requests
    ADD CONSTRAINT performance_rollup_requests_day_fkey FOREIGN KEY (day) REFERENCES public.performance_rollups(day) ON DELETE CASCADE;


--
-- Name: photo_claims photo_claims_photo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_claims
    ADD CONSTRAINT photo_claims_photo_id_fkey FOREIGN KEY (photo_id) REFERENCES public.photos(id) ON DELETE CASCADE;


--
-- Name: post_edits post_edits_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_edits
    ADD CONSTRAINT post_edits_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_link_checks post_link_checks_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_link_checks
    ADD CONSTRAINT post_link_checks_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: project_tags project_tags_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_tags project_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: share_group_files share_group_files_share_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_share_group_id_fkey FOREIGN KEY (share_group_id) REFERENCES public.share_groups(id) ON DELETE CASCADE;


--
-- Name: share_group_files share_group_files_short_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_group_files
    ADD CONSTRAINT share_group_files_short_code_id_fkey FOREIGN KEY (short_code_id) REFERENCES public.short_codes(id) ON DELETE CASCADE;


--
-- Name: share_groups share_groups_short_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_groups
    ADD CONSTRAINT share_groups_short_code_id_fkey FOREIGN KEY (short_code_id) REFERENCES public.short_codes(id) ON DELETE CASCADE;


--
-- Name: short_link_checks short_link_checks_short_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_link_checks
    ADD CONSTRAINT short_link_checks_short_link_id_fkey FOREIGN KEY (short_link_id) REFERENCES public.short_links(id) ON DELETE CASCADE;


--
-- Name: short_links short_links_short_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_links
    ADD CONSTRAINT short_links_short_code_id_fkey FOREIGN KEY (short_code_id) REFERENCES public.short_codes(id) ON DELETE CASCADE;


--
-- Name: sightings sightings_api_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sightings
    ADD CONSTRAINT sightings_api_token_id_fkey FOREIGN KEY (api_token_id) REFERENCES public.api_tokens(id) ON DELETE CASCADE;


--
-- Name: sightings sightings_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sightings
    ADD CONSTRAINT sightings_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sign_ins sign_ins_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sign_ins
    ADD CONSTRAINT sign_ins_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: social_post_deliveries social_post_deliveries_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_deliveries
    ADD CONSTRAINT social_post_deliveries_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.service_connections(id) ON DELETE SET NULL;


--
-- Name: social_post_deliveries social_post_deliveries_social_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_deliveries
    ADD CONSTRAINT social_post_deliveries_social_post_id_fkey FOREIGN KEY (social_post_id) REFERENCES public.social_posts(id) ON DELETE CASCADE;


--
-- Name: social_post_parts social_post_parts_social_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_parts
    ADD CONSTRAINT social_post_parts_social_post_id_fkey FOREIGN KEY (social_post_id) REFERENCES public.social_posts(id) ON DELETE CASCADE;


--
-- Name: social_post_photos social_post_photos_photo_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_photos
    ADD CONSTRAINT social_post_photos_photo_key_fkey FOREIGN KEY (photo_key) REFERENCES public.photos(key);


--
-- Name: social_post_photos social_post_photos_social_post_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_post_photos
    ADD CONSTRAINT social_post_photos_social_post_part_id_fkey FOREIGN KEY (social_post_part_id) REFERENCES public.social_post_parts(id) ON DELETE CASCADE;


--
-- Name: social_posts social_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_posts
    ADD CONSTRAINT social_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE SET NULL;


--
-- Name: suggestion_edits suggestion_edits_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggestion_edits
    ADD CONSTRAINT suggestion_edits_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;


--
-- Name: suggestions suggestions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: suggestions suggestions_social_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_social_post_id_fkey FOREIGN KEY (social_post_id) REFERENCES public.social_posts(id) ON DELETE CASCADE;


--
-- Name: task_comments task_comments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_contributors task_contributors_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_contributors
    ADD CONSTRAINT task_contributors_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_events task_events_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_links task_links_from_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_links
    ADD CONSTRAINT task_links_from_task_id_fkey FOREIGN KEY (from_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_links task_links_to_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_links
    ADD CONSTRAINT task_links_to_task_id_fkey FOREIGN KEY (to_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_number_counters task_number_counters_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_number_counters
    ADD CONSTRAINT task_number_counters_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: task_rule_projects task_rule_projects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_projects
    ADD CONSTRAINT task_rule_projects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: task_rule_projects task_rule_projects_task_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_projects
    ADD CONSTRAINT task_rule_projects_task_rule_id_fkey FOREIGN KEY (task_rule_id) REFERENCES public.task_rules(id) ON DELETE CASCADE;


--
-- Name: task_rule_tags task_rule_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_tags
    ADD CONSTRAINT task_rule_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: task_rule_tags task_rule_tags_task_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_rule_tags
    ADD CONSTRAINT task_rule_tags_task_rule_id_fkey FOREIGN KEY (task_rule_id) REFERENCES public.task_rules(id) ON DELETE CASCADE;


--
-- Name: task_series task_series_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_series
    ADD CONSTRAINT task_series_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_sources task_sources_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_sources
    ADD CONSTRAINT task_sources_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_tags task_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE CASCADE;


--
-- Name: task_tags task_tags_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.task_series(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_sprint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_sprint_id_fkey FOREIGN KEY (sprint_id) REFERENCES public.sprints(id) ON DELETE RESTRICT;


--
-- Name: webmention_receipts webmention_receipts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webmention_receipts
    ADD CONSTRAINT webmention_receipts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: webmentions webmentions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webmentions
    ADD CONSTRAINT webmentions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: work_sessions work_sessions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--


SET search_path TO "$user", public;

INSERT INTO schema_migrations (filename) VALUES
('20260928000001_create_shared_domains.rb'),
('20260928000002_create_webmention_settings.rb'),
('20260928000003_create_session_validity.rb'),
('20260928000004_create_tags.rb'),
('20260928000005_create_posts.rb'),
('20260928000006_create_post_tags.rb'),
('20260928000007_create_webmentions.rb'),
('20260928000008_create_webmention_receipts.rb'),
('20260928000009_create_social_posts.rb'),
('20260928000010_create_social_post_parts.rb'),
('20260928000011_create_social_post_deliveries.rb'),
('20260928000012_create_messages.rb'),
('20260928000013_create_analytics_events.rb'),
('20260928000014_create_analytics_rollups.rb'),
('20260928000015_create_analytics_rollup_paths.rb'),
('20260928000016_create_analytics_rollup_referrers.rb'),
('20260928000017_create_analytics_rollup_countries.rb'),
('20260928000018_create_sync_states.rb'),
('20260928000019_create_commits.rb'),
('20260928000020_create_journal_entries.rb'),
('20260928000021_create_journal_entry_tags.rb'),
('20260928000022_create_projects.rb'),
('20260928000023_create_project_tags.rb'),
('20260928000024_create_work_entries.rb'),
('20260928000025_create_sprints.rb'),
('20260928000026_create_task_types.rb'),
('20260928000027_create_tasks.rb'),
('20260928000028_create_task_tags.rb'),
('20260928000029_create_task_links.rb'),
('20260928000030_create_oauth_clients.rb'),
('20260928000031_create_oauth_codes.rb'),
('20260928000032_create_oauth_tokens.rb'),
('20260928000033_create_suggestions.rb'),
('20260928000034_create_suggestion_edits.rb'),
('20260928000035_create_activities_view.rb'),
('20260928000036_add_canceled_to_task_status.rb'),
('20260928000037_close_canceled_tasks.rb'),
('20260928000038_drop_task_type_from_activities.rb'),
('20260928000039_convert_task_types_to_tags.rb'),
('20260928000040_create_task_sources.rb'),
('20260928000041_add_external_to_task_list.rb'),
('20260928000042_add_issues_to_sync_name.rb'),
('20260928000043_add_remote_state_to_task_sources.rb'),
('20260928000044_add_linear_to_task_source_provider.rb'),
('20260928000045_add_started_to_task_source_state.rb'),
('20260928000046_add_linear_issues_to_sync_name.rb'),
('20260929000047_add_scope_to_tags.rb'),
('20260929000048_hold_tag_joins_to_their_scope.rb'),
('20260929000049_add_visitors_to_referrer_and_country_rollups.rb'),
('20260929000050_create_task_comments.rb'),
('20260929000051_add_task_comments_to_activities.rb'),
('20260929000052_add_paging_sort_indexes.rb'),
('20260930000053_add_ignored_to_webmention_status.rb'),
('20260930000054_create_people.rb'),
('20260930000055_create_photos.rb'),
('20260930000056_create_photo_claims.rb'),
('20260930000057_create_post_edits.rb'),
('20261001000058_create_api_tokens.rb'),
('20261001000059_create_post_deletions.rb'),
('20261001000060_add_marked_spam_at_to_messages.rb'),
('20261001000061_add_redirect_uri_sent_to_oauth_codes.rb'),
('20261001000062_create_spam_senders.rb'),
('20261001000063_add_spam_reason_to_webmentions.rb'),
('20261001000064_add_month_visitor_hash_and_create_analytics_rollup_reach.rb'),
('20261001000065_add_access_token_id_to_oauth_tokens.rb'),
('20261001000066_add_source_and_create_analytics_rollup_sources.rb'),
('20261001000067_add_checked_at_to_task_sources.rb'),
('20261001000068_create_analytics_rollup_page_referrers_and_countries.rb'),
('20261001000069_add_device_class_and_create_analytics_rollup_devices.rb'),
('20261001000070_add_scroll_depth_and_create_analytics_rollup_scroll_depths.rb'),
('20261001000071_add_referrer_path_to_analytics_events.rb'),
('20261003000072_create_held_post_follow_ups.rb'),
('20261003000073_create_held_webmentions.rb'),
('20261003000074_create_work_sessions.rb'),
('20261003000075_create_attention_view.rb'),
('20261003000076_create_search_documents.rb'),
('20261003000078_create_decisions.rb'),
('20261003000079_create_task_events.rb'),
('20261003000080_create_saved_views.rb'),
('20261003000082_create_review_views.rb'),
('20261003000094_create_record_links.rb'),
('20261003000095_add_seen_at_to_task_sources.rb'),
('20261003000096_create_task_timeline_view.rb'),
('20261003000097_create_decision_comments.rb'),
('20261003000131_create_decision_tags.rb'),
('20261003000136_add_read_throughs_to_analytics_rollup_paths.rb'),
('20261003000137_create_post_reader_hashes.rb'),
('20261003000152_add_backups_to_sync_name.rb'),
('20261003000153_create_task_tag_rules.rb'),
('20261003000154_create_decision_timeline_view.rb'),
('20261003000156_add_decisions_to_activities.rb'),
('20261003000158_create_post_reader_counts.rb'),
('20261003000176_create_feed_subscribers.rb'),
('20261003000196_create_attention_snoozes.rb'),
('20261003000214_create_analytics_clicks.rb'),
('20261003000274_create_review_decisions_view.rb'),
('20261003000335_add_work_sessions_to_activities.rb'),
('20261003000336_cascade_tag_joins_on_delete.rb'),
('20261004000404_create_review_notes.rb'),
('20261004000405_move_review_notes_out_of_the_journal.rb'),
('20261004000414_count_review_carries_from_task_events.rb'),
('20261004000415_refuse_a_tag_delete_that_empties_a_task_tag_rule.rb'),
('20261004000419_create_post_tag_removals.rb'),
('20261004000461_add_single_author_hosts_to_webmention_settings.rb'),
('20261006000507_add_provider_to_task_tag_rules.rb'),
('20261006000517_add_unsent_webmention_targets_to_posts.rb'),
('20261006000618_create_task_contributors.rb'),
('20261006000623_add_contributors_to_activity_views.rb'),
('20261006000632_add_parent_to_task_link_type.rb'),
('20261006000633_add_synced_and_one_parent_to_task_links.rb'),
('20261006000639_notify_admin_changes.rb'),
('20261007000640_replace_project_status_with_visibility.rb'),
('20261007000641_add_seen_at_to_webmentions.rb'),
('20261007000642_add_snoozed_until_to_inbox_records.rb'),
('20261007000643_rename_task_tag_rules_to_task_rules.rb'),
('20261007000650_create_sign_ins.rb'),
('20261007000651_create_sightings.rb'),
('20261007000652_create_known_devices.rb'),
('20261007000654_add_new_devices_to_attention.rb'),
('20261008000200_add_history_cursor_to_task_sources.rb'),
('20261008000300_add_country_names.rb'),
('20261008000773_add_decisions_to_search_documents.rb'),
('20261008000778_merge_overlapping_work_session_days.rb'),
('20261008000781_create_message_tags.rb'),
('20261008000795_create_service_connections.rb'),
('20261008000801_create_owner_identities.rb'),
('20261009000799_create_service_apps.rb'),
('20261009000800_deliver_social_posts_to_each_account.rb'),
('20261009000801_create_pull_requests.rb'),
('20261009000802_add_pull_requests_to_sync_name.rb'),
('20261009000803_add_pull_requests_to_activities.rb'),
('20261009000804_add_pull_requests_to_record_links_and_search.rb'),
('20261010000140_create_post_link_checks.rb'),
('20261010000420_add_broken_links_to_attention.rb'),
('20261010000440_add_scopes_and_expiry_to_api_tokens.rb'),
('20261010000870_drop_revoked_at_from_oauth_clients.rb'),
('20261010001130_move_format_checks_into_domains.rb'),
('20261010001570_notify_admin_changes_on_security_and_services.rb'),
('20261010001731_create_social_post_photos.rb'),
('20261010002210_create_short_codes_and_shares.rb'),
('20261010002450_create_short_links.rb'),
('20261011120000_add_revoked_at_to_service_connections.rb'),
('20261011130000_create_health_days.rb'),
('20261011130100_create_workouts.rb'),
('20261011130200_add_health_to_sync_name.rb'),
('20261011160000_add_health_to_api_token_scopes.rb'),
('20261011170000_add_workouts_to_activities.rb'),
('20261011180000_move_google_health_connection_to_google.rb'),
('20261011181127_move_messages_into_mail_threads.rb'),
('20261011190000_add_mail_to_api_token_scopes.rb'),
('20261011193000_add_mail_to_sync_name.rb'),
('20261011193100_add_gmail_to_mail_tables.rb'),
('20261011194000_create_calendars.rb'),
('20261011194100_add_calendar_to_sync_name.rb'),
('20261011194200_add_draft_to_mail_threads.rb'),
('20261012010000_add_mail_settings.rb'),
('20261012030000_add_signature_to_mail_accounts.rb'),
('20261012040000_add_mail_threads_to_record_links.rb'),
('20261012050000_add_recurring_id_to_calendar_events.rb'),
('20261012050100_add_work_to_service_connections.rb'),
('20261013020000_create_mail_attachments.rb'),
('20261013030000_match_owner_identities_on_email.rb'),
('20261013030100_name_the_provider_on_sign_ins.rb'),
('20261013041000_add_stage_to_tasks.rb'),
('20261013041100_add_board_published_to_projects.rb'),
('20261014181552_add_opened_at_to_pull_requests.rb'),
('20261014200244_add_linkedin_to_network.rb'),
('20261014213117_add_lapsing_connections_to_attention.rb'),
('20261014220000_create_performance_timings.rb'),
('20261014230000_create_share_groups.rb'),
('20261014231253_create_performance_pages.rb'),
('20261014231500_create_task_series.rb'),
('20261014233000_create_performance_rollups.rb'),
('20261014234500_add_recurred_to_task_event_kind.rb'),
('20261014235100_ignore_bookkeeping_in_notify_admin_change.rb'),
('20261015000100_add_key_to_projects.rb'),
('20261015000200_move_task_projects_onto_tasks.rb'),
('20261015000300_add_relation_to_record_links.rb'),
('20261015001000_backfill_task_projects_and_tags_from_rules.rb'),
('20261015003000_add_sync_token_to_calendars.rb'),
('20261015010000_add_number_to_tasks.rb'),
('20261015080000_add_rendered_body_to_posts.rb'),
('20261015090000_add_widths_to_photos.rb'),
('20261015100000_index_activity_dates_moved_task_events_and_delivery_connections.rb'),
('20261015110000_add_settings_synced_at_to_mail_accounts.rb'),
('20261015120000_create_analytics_rollup_hours.rb'),
('20261015120010_backfill_analytics_rollup_hours.rb'),
('20261015130000_add_preview_to_activities.rb'),
('20261015140000_count_task_numbers_per_scope.rb'),
('20261015150700_index_waiting_mail_threads.rb'),
('20261015180200_index_mail_message_letters.rb'),
('20261015230200_add_backfill_page_to_mail_accounts.rb'),
('20261015231400_add_first_failed_at_to_post_link_checks.rb'),
('20261016001000_merge_shares_into_share_group_files.rb'),
('20261016001451_add_name_to_share_groups.rb'),
('20261016001466_create_public_search_documents.rb'),
('20261016001468_create_search_attempts.rb'),
('20261016001470_create_short_link_checks.rb'),
('20261016001471_create_link_check_runs.rb'),
('20261016001473_notify_admin_changes_on_post_link_checks.rb'),
('20261016001474_notify_admin_changes_on_short_link_checks.rb'),
('20261016002022_add_auto_approve_likes_and_reposts_to_webmention_settings.rb'),
('20261016002032_create_trusted_authors.rb'),
('20261016002057_add_synced_from_to_calendars.rb'),
('20261016002066_defer_mail_label_name_check.rb'),
('20261016002072_claim_decision_photos.rb'),
('20261016002074_add_description_to_tags.rb'),
('20261016002086_keep_manual_work_session_days_positive.rb'),
('20261016002092_add_task_rules_for_project_repos.rb'),
('20261016002183_let_task_positions_go_below_one.rb'),
('20261016002186_index_commits_created_at.rb'),
('20261016002204_create_held_title_fetches_and_backfills.rb'),
('20261016002242_keep_the_pull_request_import_edge_in_sync_states.rb'),
('20261016002252_index_commit_text_by_trigram.rb'),
('20261016002255_store_journal_html_and_word_counts.rb'),
('20261016002262_drop_covered_indexes.rb'),
('20261017190000_add_error_to_performance_jobs.rb'),
('20261017190100_add_agents_to_api_token_scopes.rb'),
('20261017190110_create_memory_files.rb'),
('20261017210004_create_artifacts.rb'),
('20261017230003_add_schedule_key_to_performance_jobs.rb'),
('20261017230004_create_agent_sessions.rb'),
('20261018010004_add_memory_files_and_artifacts_to_record_links.rb'),
('20261018080001_add_earlier_author_to_memory_events.rb'),
('20261018080004_add_visitor_hash_to_sign_ins.rb'),
('20261018080007_add_series_id_to_tasks.rb'),
('20261018090001_store_plain_line_breaks.rb'),
('20261018090002_add_preview_key_to_share_group_files.rb'),
('20261018100006_index_agent_events_by_created_at_and_revert.rb'),
('20261018110003_ignore_sync_bookkeeping_in_notify_admin_change.rb'),
('20261018110004_index_performance_requests_by_route.rb'),
('20261018140004_add_draft_to_mail_messages.rb'),
('20261018150007_type_token_scopes_as_oauth_scope.rb'),
('20261018200001_renumber_tasks_with_no_project.rb'),
('20261019160000_pad_short_codes.rb'),
('20261019160001_drop_memory_fact_text_length_check.rb'),
('20261020100000_add_description_to_memory_files.rb'),
('20261020210000_require_memory_file_description.rb'),
('20261021020000_add_describe_to_memory_event_op.rb'),
('20261021030000_create_agent_session_index_lines.rb'),
('20261021110000_drop_short_code_length.rb'),
('20261021120000_create_agent_session_searches.rb'),
('20261021140000_create_agent_session_reads.rb'),
('20261021200000_add_project_id_to_agent_sessions.rb'),
('20261021210000_drop_repo_from_memory_scope.rb'),
('20261022100000_create_notes.rb'),
('20261022110000_grow_people_into_contacts.rb'),
('20261022120000_create_devices.rb'),
('20261022130000_add_dismissed_at_to_sign_ins.rb'),
('20261022140000_key_sightings_on_product.rb'),
('20261022150000_add_contacts_to_sync_name.rb'),
('20261022150100_add_contact_sync.rb'),
('20261022200000_create_note_links.rb'),
('20261022220000_add_signed_out_at_to_devices.rb'),
('20261023030000_add_notes_to_search_documents.rb');
