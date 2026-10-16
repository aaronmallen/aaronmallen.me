# frozen_string_literal: true

module Posts
  module Relations
    class Posts < Blog::DB::Relation
      PUBLISHED = Blog::Types::PostStatus["published"]
      ROW = %i[
        id title slug status published_at created_at updated_at summary first_paragraph read_time word_count
        webmentions_enabled webmention_targets unsent_webmention_targets syndication_enabled syndication_targets
        og_title og_image_url canonical_url
      ].freeze
      SCHEDULED = Blog::Types::PostStatus["scheduled"]
      SHARED_TAG = Sequel[:post_tags][:tag_id]
      MOST_SHARED = Sequel.function(:count, SHARED_TAG).desc
      TERM_ORDER = [
        Sequel.desc(Sequel.expr("A" => Sequel.function(:any, :weights))),
        Sequel.desc(Sequel.function(:cardinality, :positions)),
        :lexeme,
      ].freeze
      VECTOR = Sequel[:posts][:search_vector]

      schema :posts, infer: true do
        associations do
          has_many :post_tags
          has_many :tags, through: :post_tags, view: :in_name_order
        end
      end

      def dated_between(first, last)
        started = first ? where { published_at >= first } : self
        last ? started.where { published_at < last } : started
      end

      def due_at(time) = with_status(SCHEDULED).where { published_at <= time }

      def last_changed_at
        unordered.max(Sequel.function(:greatest, self[:published_at].qualified, self[:updated_at].qualified))
      end

      def lean = select(*ROW).combine(:tags)

      def linkable = linkables(title: :title, day: self.class.site_day(:published_at, :created_at))

      def matching(text) = containing(text, :title, :summary, :body)

      def newer_than(post) = where(published_order > [post.published_at, post.id])

      def newest_first = order(*newest_order)

      def older_than(post) = where(published_order < [post.published_at, post.id])

      def oldest_first = order(self[:published_at].asc, self[:id].asc)

      def publish(at)
        published_at = Sequel.function(:least, Sequel.function(:coalesce, :published_at, at), at)

        stamped(:update, result: :many).call(status: PUBLISHED, published_at:)
      end

      def published = where(status: PUBLISHED)

      def scheduled = with_status(SCHEDULED)

      def scheduled_or_published = with_status([SCHEDULED, PUBLISHED])

      def sharing_tags_with(post_id)
        tag_ids = dataset.db[:post_tags].where(post_id:).select(:tag_id)

        join(:post_tags).where(SHARED_TAG => tag_ids).group(self[:id]).order(MOST_SHARED, *newest_order)
      end

      def tagged(tag) = join(:tags).where(Sequel[:tags][:name] => tag)

      def top_terms(post_id, limit)
        lexemes = dataset.db.from(:posts, Sequel.function(:unnest, VECTOR)).where(Sequel[:posts][:id] => post_id)

        lexemes.order(*TERM_ORDER).limit(limit).select_map(:lexeme)
      end

      def unpublished = exclude(status: PUBLISHED)

      def with_ids(ids) = where(id: ids)

      def with_slug(slug) = where(slug:)

      def with_status(status) = where(status:)

      def without(ids) = exclude(self[:id].qualified => ids)

      def worded_like(terms)
        return none if terms.empty?

        query = Sequel.cast(terms.map { quoted_term(it) }.join(" | "), :tsquery)

        where(Sequel.lit("? @@ ?", VECTOR, query))
          .order(Sequel.function(:ts_rank, VECTOR, query).desc, *newest_order)
      end

      private

      def newest_order = [self[:published_at].desc, self[:id].desc]

      def published_order = Sequel.expr([self[:published_at], self[:id]])

      def quoted_term(term) = "'#{term.gsub(/['\\]/) { "\\#{it}" }}'"
    end
  end
end
