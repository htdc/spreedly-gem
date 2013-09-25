module Spreedly

  module SslRequester

    def ssl_get(endpoint, headers, talking_to_gateway = false)
      ssl_request(:get, endpoint, nil, headers, talking_to_gateway)
    end

    def ssl_post(endpoint, body, headers, talking_to_gateway = false)
      ssl_request(:post, endpoint, body, headers, talking_to_gateway)
    end

    def ssl_raw_get(endpoint, headers = {})
      ssl_request(:get, endpoint, nil, headers, false, true)
    end

    def ssl_put(endpoint, body, headers, talking_to_gateway = false)
      ssl_request(:put, endpoint, body, headers, talking_to_gateway)
    end

    def ssl_options(endpoint, talking_to_gateway = false)
      ssl_request(:options, endpoint, nil, {}, talking_to_gateway)
    end

    private
    def ssl_request(method, endpoint, body, headers, talking_to_gateway, return_raw = false)
      how_long = talking_to_gateway ? 66 : 10
      raw_response = Timeout::timeout(how_long) do
        raw_ssl_request(method, endpoint, body, headers)
      end

      show_raw_response(raw_response)
      handle_response(raw_response, return_raw)

    rescue Timeout::Error => e
      raise Spreedly::TimeoutError.new
    end

    def raw_ssl_request(method, endpoint, body, headers = {})
      connection = Spreedly::Connection.new(endpoint)
      connection.request(method, body, headers)
    end

    def handle_response(response, return_raw = false)
      case response.code.to_i
      when 200...300
        if return_raw
          response.body
        else
          xml_doc(response)
        end
      when 401
        raise AuthenticationError.new(xml_doc(response))
      when 404
        raise NotFoundError.new(xml_doc(response))
      when 402
        raise PaymentRequiredError.new(xml_doc(response))
      when 422
        if xml_doc(response).at_xpath('.//errors/error')
          raise TransactionCreationError.new(xml_doc(response))
        else
          xml_doc(response)
        end
      else
        raise UnexpectedResponseError.new(response)
      end
    end

    def  xml_doc(response)
      Nokogiri::XML(response.body)
    end

    def show_raw_response(raw_response)
      return unless ENV['SHOW_RAW_RESPONSE'] == 'true'
      puts raw_response.inspect
      puts "\nraw_response.code: #{raw_response.code}\nraw_response.body:\n#{raw_response.body}"
    end

  end

end
