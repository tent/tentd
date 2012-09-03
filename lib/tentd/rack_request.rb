require 'rack/request'

# All this so that we can have duplicate multipart names.
module TentD
  class RackRequest < Rack::Request
    # Use our custom multipart parser
    def parse_multipart(env)
      RackMultipartParser.new(env).parse
    end
  end

  class RackMultipartParser < Rack::Multipart::Parser
    # Rack::Multipart::Parser#parse with the Utils.normalize_params call swapped
    # out for ours.
    def parse
      return nil unless setup_parse

      fast_forward_to_first_boundary

      loop do
        head, filename, content_type, name, body =
          get_current_head_and_filename_and_content_type_and_name_and_body

        if i = @buf.index(rx)
          body << @buf.slice!(0, i)
          @buf.slice!(0, @boundary_size+2)

          @content_length = -1  if $1 == "--"
        end

        filename, data = get_data(filename, body, content_type, name, head)

        # use our custom multipart param parser instead of Rack::Utils
        normalize_params(@params, name, data) unless data.nil?

        break if (@buf.empty? && $1 != EOL) || @content_length == -1
      end

      @io.rewind

      @params.to_params_hash
    end

    # Instead of making a params hash using the names, make an array of parts
    # under the key 'attachments'.
    def normalize_params(params, name, v = nil)
      (params['attachments'] ||= []) << v
      params
    end
  end
end
