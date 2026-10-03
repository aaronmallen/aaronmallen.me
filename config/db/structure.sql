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
-- Name: code_challenge_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.code_challenge_method AS ENUM (
    'S256'
);


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
    'mastodon'
);


--
-- Name: non_blank_text; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.non_blank_text AS text
	CONSTRAINT non_blank_text_check CHECK ((VALUE ~ '\S'::text));


--
-- Name: oauth_token_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oauth_token_type AS ENUM (
    'access',
    'refresh'
);


--
-- Name: photo_owner; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.photo_owner AS ENUM (
    'post',
    'journal_entry',
    'task',
    'task_comment'
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
-- Name: project_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.project_status AS ENUM (
    'active',
    'wip',
    'paused',
    'archived'
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
    'linear_issues'
);


--
-- Name: sync_state_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_state_kind AS ENUM (
    'commits',
    'backfill',
    'failure'
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
-- Name: task_event_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_event_kind AS ENUM (
    'moved',
    'tagged',
    'untagged',
    'status_changed'
);


--
-- Name: task_link_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_link_type AS ENUM (
    'blocks',
    'relates',
    'duplicates'
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
-- Name: journal_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entries (
    id integer NOT NULL,
    entry_date date NOT NULL,
    entry_time time without time zone NOT NULL,
    body public.non_blank_text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, COALESCE((body)::text, ''::text)), 'B'::"char")) STORED
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
    status public.project_status DEFAULT 'active'::public.project_status NOT NULL,
    featured boolean DEFAULT false NOT NULL,
    "position" integer NOT NULL,
    started_on date,
    archived_on date,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    og_image_url text,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((name)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE(tagline, ''::text) || ' '::text) || COALESCE((repo)::text, ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT projects_archived_on_check CHECK (((archived_on IS NULL) OR (status = 'archived'::public.project_status))),
    CONSTRAINT projects_archived_order_check CHECK ((archived_on >= started_on)),
    CONSTRAINT projects_position_check CHECK (("position" > 0)),
    CONSTRAINT projects_stars_check CHECK ((stars >= 0))
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
    CONSTRAINT tasks_carried_count_check CHECK ((carried_count >= 0)),
    CONSTRAINT tasks_completed_at_check CHECK (((status = ANY (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) = (completed_at IS NOT NULL))),
    CONSTRAINT tasks_list_or_sprint_check CHECK ((num_nonnulls(list, sprint_id) = 1)),
    CONSTRAINT tasks_position_check CHECK (("position" > 0)),
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
    CONSTRAINT webmentions_source_url_check CHECK ((octet_length((source_url)::text) <= 2048)),
    CONSTRAINT webmentions_spam_reason_check CHECK (((status = 'spam'::public.webmention_status) OR (spam_reason IS NULL)))
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
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    tasks.id AS task_id
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
    (projects.status)::text AS status,
    NULL::public.network[] AS targets,
    projects.tagline AS excerpt,
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    NULL::integer AS task_id
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
    task_comments.task_id
   FROM (public.task_comments
     JOIN public.tasks ON ((tasks.id = task_comments.task_id)));


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
    CONSTRAINT analytics_rollup_paths_bounces_check CHECK (((bounces >= 0) AND (bounces <= visitors))),
    CONSTRAINT analytics_rollup_paths_counts_check CHECK (((views >= 0) AND (visitors >= 0) AND (read_seconds >= 0) AND (visitors <= views)))
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
    CONSTRAINT api_tokens_name_length_check CHECK ((char_length((name)::text) <= 100))
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
-- Name: attention; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.attention AS
 SELECT 'carried'::text AS kind,
    tasks.id AS record_id,
    (tasks.title)::text AS title,
    ((tasks.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    tasks.carried_count
   FROM public.tasks
  WHERE ((tasks.status <> ALL (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) AND (tasks.carried_count > 0))
UNION ALL
 SELECT 'draft'::text AS kind,
    posts.id AS record_id,
    posts.title,
    ((posts.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count
   FROM public.posts
  WHERE (posts.status = 'draft'::public.post_status)
UNION ALL
 SELECT 'someday'::text AS kind,
    tasks.id AS record_id,
    (tasks.title)::text AS title,
    ((tasks.updated_at AT TIME ZONE 'America/Chicago'::text))::date AS touched_on,
    NULL::integer AS carried_count
   FROM public.tasks
  WHERE ((tasks.status <> ALL (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) AND (tasks.list = 'someday'::public.task_list))
UNION ALL
 SELECT 'journal'::text AS kind,
    NULL::integer AS record_id,
    NULL::text AS title,
    max(journal_entries.entry_date) AS touched_on,
    NULL::integer AS carried_count
   FROM public.journal_entries
 HAVING (count(*) > 0);


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
    CONSTRAINT decisions_choice_check CHECK (((status = 'resolved'::public.decision_status) = (resolved_option_id IS NOT NULL)))
);


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
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    reply_to public.email_address NOT NULL,
    subject public.non_blank_text NOT NULL,
    body public.non_blank_text NOT NULL,
    status public.message_status DEFAULT 'unread'::public.message_status NOT NULL,
    visitor_hash public.visitor_hash NOT NULL,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    marked_spam_at timestamp with time zone,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((subject)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((COALESCE((body)::text, ''::text) || ' '::text) || COALESCE((reply_to)::text, ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT messages_marked_spam_at_check CHECK (((status = 'spam'::public.message_status) = (marked_spam_at IS NOT NULL)))
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.messages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
    revoked_at timestamp with time zone,
    last_used_at timestamp with time zone,
    CONSTRAINT oauth_clients_redirect_uris_check CHECK ((cardinality(redirect_uris) > 0))
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
    scopes text[] DEFAULT '{read}'::text[] NOT NULL,
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
    scopes text[] DEFAULT '{read}'::text[] NOT NULL,
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
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id integer NOT NULL,
    key text NOT NULL,
    name public.non_blank_text NOT NULL,
    mastodon_handle text,
    bluesky_handle text,
    bluesky_did text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((name)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, ((((COALESCE(key, ''::text) || ' '::text) || COALESCE(mastodon_handle, ''::text)) || ' '::text) || COALESCE(bluesky_handle, ''::text))), 'B'::"char"))) STORED,
    CONSTRAINT people_bluesky_did_check CHECK (((bluesky_handle IS NULL) = (bluesky_did IS NULL))),
    CONSTRAINT people_handles_check CHECK ((num_nonnulls(mastodon_handle, bluesky_handle) > 0)),
    CONSTRAINT people_key_check CHECK ((key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT people_mastodon_handle_check CHECK ((mastodon_handle ~ '^@[^@\s]+@[^@\s]+$'::text))
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
    key text NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    byte_size integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT photos_key_check CHECK ((key ~ '^[0-9a-f]{32}\.(gif|jpg|png|webp)$'::text)),
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
-- Name: review_tasks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.review_tasks AS
 SELECT tasks.id AS task_id,
    (tasks.title)::text AS title,
    (tasks.status)::text AS status,
    ((tasks.completed_at AT TIME ZONE 'America/Chicago'::text))::date AS closed_on,
    tasks.worked_seconds,
    tasks.carried_count,
    sprints.sprint_date
   FROM (public.tasks
     LEFT JOIN public.sprints ON ((sprints.id = tasks.sprint_id)));


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
    (projects.status)::text AS status,
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
    (people.name)::text AS title,
    ((((((COALESCE((people.name)::text, ''::text) || '
'::text) || COALESCE(people.key, ''::text)) || '
'::text) || COALESCE(people.mastodon_handle, ''::text)) || '
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
 SELECT 'message'::text AS kind,
    messages.id AS source_id,
    (messages.subject)::text AS title,
    ((((COALESCE((messages.subject)::text, ''::text) || '
'::text) || COALESCE((messages.body)::text, ''::text)) || '
'::text) || COALESCE((messages.reply_to)::text, ''::text)) AS body,
    ((messages.received_at AT TIME ZONE 'America/Chicago'::text))::date AS day,
    (messages.status)::text AS status,
    NULL::text AS slug,
    NULL::text AS repo,
    NULL::text AS sha,
    NULL::text AS url,
    messages.search_vector
   FROM public.messages
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
   FROM public.webmentions;


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
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name public.tag_name NOT NULL,
    color public.tag_color NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scope public.tag_scope NOT NULL
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
    ELSE ((tag_name IS NOT NULL) AND (num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, from_status, to_status) = 0))
END)
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
    checked_at timestamp with time zone
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
-- Name: work_session_days; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_session_days AS
 SELECT work_sessions.task_id,
    (days.day)::date AS worked_on,
    (floor(EXTRACT(epoch FROM (LEAST(COALESCE(work_sessions.ended_at, now()), ((days.day + '1 day'::interval) AT TIME ZONE 'America/Chicago'::text)) - GREATEST(work_sessions.started_at, (days.day AT TIME ZONE 'America/Chicago'::text))))))::integer AS seconds
   FROM (public.work_sessions
     CROSS JOIN LATERAL generate_series((((work_sessions.started_at AT TIME ZONE 'America/Chicago'::text))::date)::timestamp without time zone, (((COALESCE(work_sessions.ended_at, now()) AT TIME ZONE 'America/Chicago'::text))::date)::timestamp without time zone, '1 day'::interval) days(day));


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
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);


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
-- Name: decisions decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (id);


--
-- Name: held_post_follow_ups held_post_follow_ups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_post_follow_ups
    ADD CONSTRAINT held_post_follow_ups_pkey PRIMARY KEY (id);


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
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


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
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


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
-- Name: session_validity session_validity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_validity
    ADD CONSTRAINT session_validity_pkey PRIMARY KEY (id);


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
-- Name: analytics_rollup_countries_day_country_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_countries_day_country_code_index ON public.analytics_rollup_countries USING btree (day, country_code) NULLS NOT DISTINCT;


--
-- Name: analytics_rollup_devices_day_path_device_class_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_devices_day_path_device_class_index ON public.analytics_rollup_devices USING btree (day, path, device_class) NULLS NOT DISTINCT;


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
-- Name: commits_commit_date_commit_time_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_commit_date_commit_time_id_index ON public.commits USING btree (commit_date, commit_time, id);


--
-- Name: commits_commit_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_commit_date_index ON public.commits USING btree (commit_date);


--
-- Name: commits_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_search_vector_index ON public.commits USING gin (search_vector);


--
-- Name: decision_events_decision_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_events_decision_id_created_at_index ON public.decision_events USING btree (decision_id, created_at);


--
-- Name: decision_events_decision_id_option_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decision_events_decision_id_option_id_index ON public.decision_events USING btree (decision_id, option_id);


--
-- Name: decisions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX decisions_status_index ON public.decisions USING btree (status);


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
-- Name: journal_entries_entry_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entries_entry_date_index ON public.journal_entries USING btree (entry_date);


--
-- Name: journal_entries_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entries_search_vector_index ON public.journal_entries USING gin (search_vector);


--
-- Name: journal_entry_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entry_tags_tag_id_index ON public.journal_entry_tags USING btree (tag_id);


--
-- Name: messages_marked_spam_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_marked_spam_at_index ON public.messages USING btree (marked_spam_at);


--
-- Name: messages_received_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_received_at_id_index ON public.messages USING btree (received_at, id);


--
-- Name: messages_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_search_vector_index ON public.messages USING gin (search_vector);


--
-- Name: messages_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_status_index ON public.messages USING btree (status);


--
-- Name: messages_visitor_hash_received_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_visitor_hash_received_at_index ON public.messages USING btree (visitor_hash, received_at);


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
-- Name: people_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX people_key_index ON public.people USING btree (key);


--
-- Name: people_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX people_search_vector_index ON public.people USING gin (search_vector);


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
-- Name: projects_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_position_index ON public.projects USING btree ("position");


--
-- Name: projects_repo_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_repo_index ON public.projects USING btree (repo);


--
-- Name: projects_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_search_vector_index ON public.projects USING gin (search_vector);


--
-- Name: projects_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_status_index ON public.projects USING btree (status);


--
-- Name: saved_views_screen_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_views_screen_name_index ON public.saved_views USING btree (screen, name);


--
-- Name: social_post_deliveries_social_post_id_network_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_deliveries_social_post_id_network_index ON public.social_post_deliveries USING btree (social_post_id, network);


--
-- Name: social_post_parts_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_post_parts_search_vector_index ON public.social_post_parts USING gin (search_vector);


--
-- Name: social_post_parts_social_post_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_parts_social_post_id_position_index ON public.social_post_parts USING btree (social_post_id, "position");


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
-- Name: task_events_task_id_occurred_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_task_id_occurred_at_index ON public.task_events USING btree (task_id, occurred_at);


--
-- Name: task_links_from_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_links_from_task_id_index ON public.task_links USING btree (from_task_id);


--
-- Name: task_links_pair_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_links_pair_key ON public.task_links USING btree (LEAST(from_task_id, to_task_id), GREATEST(from_task_id, to_task_id));


--
-- Name: task_links_to_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_links_to_task_id_index ON public.task_links USING btree (to_task_id);


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
-- Name: tasks_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_search_vector_index ON public.tasks USING gin (search_vector);


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
-- Name: work_sessions_task_id_started_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_sessions_task_id_started_at_index ON public.work_sessions USING btree (task_id, started_at);


--
-- Name: posts posts_default_webmentions_enabled; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_default_webmentions_enabled BEFORE INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_default_webmentions_enabled();


--
-- Name: posts posts_lock_published_slug; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_lock_published_slug BEFORE UPDATE OF slug ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_lock_published_slug();


--
-- Name: posts posts_record_deletion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_record_deletion AFTER DELETE ON public.posts FOR EACH ROW WHEN ((old.status = 'published'::public.post_status)) EXECUTE FUNCTION public.posts_record_deletion();


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
    ADD CONSTRAINT journal_entry_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE RESTRICT;


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
-- Name: post_tags post_tags_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE RESTRICT;


--
-- Name: project_tags project_tags_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_tags project_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE RESTRICT;


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
-- Name: task_sources task_sources_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_sources
    ADD CONSTRAINT task_sources_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_tags task_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_tag_id_fkey FOREIGN KEY (tag_id, tag_scope) REFERENCES public.tags(id, scope) ON DELETE RESTRICT;


--
-- Name: task_tags task_tags_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


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
('20261003000082_create_review_views.rb');
