module TentD
  class Feed

    class Pagination
      attr_reader :feed
      def initialize(feed)
        @feed = feed
      end

      def base_params
        @base_params ||= begin
          params = feed.params.dup
          %w( before since until ).each { |k| params.delete(k) }
          params
        end
      end

      def first_params
        return unless feed.models.any?

        params = base_params.dup

        until_post = feed.models.first
        params['until'] = [until_post.published_at, until_post.version].join(' ')

        params
      end

      def last_params
        return unless feed.models.any?

        params = base_params.dup

        params['since'] = 0

        before_post = feed.models.last
        params['before'] = [before_post.published_at, before_post.version].join(' ')

        params
      end

      def next_params
        return unless feed.models.any?

        params = base_params.dup

        before_post = feed.models.last
        params['before'] = [before_post.published_at, before_post.version].join(' ')

        params
      end

      def prev_params
        return unless feed.models.any?

        params = base_params.dup

        since_post = feed.models.first
        params['since'] = [since_post.published_at, since_post.version].join(' ')

        params
      end

      def serialize_params(params)
        query = params.inject([]) do |memo, (key, val)|
          if Array === val && key.to_s == 'mentions'
            val.each { |v| memo.push("#{key}=#{URI.encode_www_form_component(v)}") }
          elsif Array === val
            memo.push("#{key}=#{val.map { |v| URI.encode_www_form_component(v) }.join(',') }")
          else
            memo.push("#{key}=#{URI.encode_www_form_component(val)}")
          end
          memo
        end.join('&')

        "?#{query}"
      end

      def as_json(options = {})
        {
          :first => first_params,
          :last => last_params,
          :next => next_params,
          :prev => prev_params
        }.inject({}) { |memo, (k,v)|
          memo[k] = serialize_params(v) if v
          memo
        }
      end
    end

  end
end
