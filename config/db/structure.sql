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
-- Name: repo_name; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.repo_name AS text
	CONSTRAINT repo_name_check CHECK ((VALUE ~ '^[a-z0-9][a-z0-9-]*/[a-z0-9._-]+$'::text));


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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    CONSTRAINT tasks_carried_count_check CHECK ((carried_count >= 0)),
    CONSTRAINT tasks_completed_at_check CHECK (((status = ANY (ARRAY['done'::public.task_status, 'canceled'::public.task_status])) = (completed_at IS NOT NULL))),
    CONSTRAINT tasks_list_or_sprint_check CHECK ((num_nonnulls(list, sprint_id) = 1)),
    CONSTRAINT tasks_position_check CHECK (("position" > 0))
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
    CONSTRAINT webmentions_source_url_check CHECK ((octet_length((source_url)::text) <= 2048))
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
    NULL::text AS excerpt
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
    NULL::text AS excerpt
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
    NULL::text AS excerpt
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
    NULL::text AS excerpt
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
    webmentions.excerpt
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
    NULL::text AS excerpt
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
    projects.tagline AS excerpt
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
    NULL::text AS excerpt
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
    NULL::text AS excerpt
   FROM ((public.suggestions
     LEFT JOIN public.posts ON ((posts.id = suggestions.post_id)))
     LEFT JOIN LATERAL ( SELECT social_post_parts.body
           FROM public.social_post_parts
          WHERE (social_post_parts.social_post_id = suggestions.social_post_id)
          ORDER BY social_post_parts."position"
         LIMIT 1) first_part ON (true));


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
    CONSTRAINT analytics_rollup_countries_views_check CHECK ((views >= 0))
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
-- Name: analytics_rollup_referrers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_rollup_referrers (
    id integer NOT NULL,
    day date NOT NULL,
    host public.hostname,
    views integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT analytics_rollup_referrers_views_check CHECK ((views >= 0))
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
    tag_id integer NOT NULL
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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
-- Name: post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL
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
    tag_id integer NOT NULL
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    filename text NOT NULL
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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    remote_state public.task_source_state DEFAULT 'open'::public.task_source_state NOT NULL
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
    tag_id integer NOT NULL
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
    CONSTRAINT work_entries_from_year_check CHECK ((from_year > 0)),
    CONSTRAINT work_entries_position_check CHECK (("position" > 0)),
    CONSTRAINT work_entries_to_year_check CHECK (((to_year IS NULL) OR (to_year >= from_year)))
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
-- Name: analytics_rollup_paths analytics_rollup_paths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_paths
    ADD CONSTRAINT analytics_rollup_paths_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollup_referrers analytics_rollup_referrers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_referrers
    ADD CONSTRAINT analytics_rollup_referrers_pkey PRIMARY KEY (id);


--
-- Name: analytics_rollups analytics_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollups
    ADD CONSTRAINT analytics_rollups_pkey PRIMARY KEY (day);


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
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


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
-- Name: analytics_rollup_paths_day_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_paths_day_path_index ON public.analytics_rollup_paths USING btree (day, path);


--
-- Name: analytics_rollup_referrers_day_host_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analytics_rollup_referrers_day_host_index ON public.analytics_rollup_referrers USING btree (day, host) NULLS NOT DISTINCT;


--
-- Name: commits_commit_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_commit_date_index ON public.commits USING btree (commit_date);


--
-- Name: journal_entries_entry_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entries_entry_date_index ON public.journal_entries USING btree (entry_date);


--
-- Name: journal_entry_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX journal_entry_tags_tag_id_index ON public.journal_entry_tags USING btree (tag_id);


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
-- Name: projects_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_status_index ON public.projects USING btree (status);


--
-- Name: social_post_deliveries_social_post_id_network_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_post_deliveries_social_post_id_network_index ON public.social_post_deliveries USING btree (social_post_id, network);


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
-- Name: webmentions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webmentions_status_index ON public.webmentions USING btree (status);


--
-- Name: work_entries_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_entries_position_index ON public.work_entries USING btree ("position");


--
-- Name: posts posts_default_webmentions_enabled; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_default_webmentions_enabled BEFORE INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_default_webmentions_enabled();


--
-- Name: posts posts_lock_published_slug; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_lock_published_slug BEFORE UPDATE OF slug ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_lock_published_slug();


--
-- Name: analytics_rollup_countries analytics_rollup_countries_day_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_rollup_countries
    ADD CONSTRAINT analytics_rollup_countries_day_fkey FOREIGN KEY (day) REFERENCES public.analytics_rollups(day) ON DELETE CASCADE;


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
-- Name: journal_entry_tags journal_entry_tags_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_tags
    ADD CONSTRAINT journal_entry_tags_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id) ON DELETE CASCADE;


--
-- Name: journal_entry_tags journal_entry_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_tags
    ADD CONSTRAINT journal_entry_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE RESTRICT;


--
-- Name: oauth_codes oauth_codes_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_tokens oauth_tokens_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE RESTRICT;


--
-- Name: project_tags project_tags_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_tags project_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_tags
    ADD CONSTRAINT project_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE RESTRICT;


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
    ADD CONSTRAINT task_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE RESTRICT;


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
('20260928000046_add_linear_issues_to_sync_name.rb');
