module RouterHelper

  def rest_client_url(url, _payload = {})
    payload = _payload[:params] || {}
    payload[:referer_service] = current_micro_service_name
    headers = {"#{jwt_header_name}" => jwt_header_token}
    headers = headers.merge(_payload[:headers]) if _payload[:headers]
    verb = _payload[:method]
    begin
      data = RestClient::Request.execute(method: verb, url: url, payload: payload, headers: headers)
      data = {code: data.code, data: JSON.parse(data.body), headers: data.headers, cookies: data.cookies}
    rescue RestClient::Unauthorized, RestClient::Forbidden => err
      data = JSON.parse(err.response)
    rescue RestClient::ResourceNotFound => err
      data = {code: 404, error: "Url not found #{_req.url}" }
    rescue RestClient::InternalServerError => err
      data = {code: 500, error: "Url not found #{_req.url}" }  
    end
    data
  end

  def services_development_urls
    @_services_development_urls ||= {user: {url: "http://localhost", port: 3000},
            practice: {url: "http://localhost", port: 3001},
            mocktest: {url: "http://localhost", port: 3002},
            payment: {url: "http://localhost", port: 3003},
            content: {url: "http://localhost", port: 3004},          
            }
  end

  def services_uri
    @_services_uri ||= send("services_#{Rails.env}_urls")
  end

  def services_production_urls
    @_services_production_urls ||= {user: {url: "http://user.embibe.com", port: nil},
            mocktest: {url: "http://mocktest.embibe.com", port: nil},
            practice: {url: "http://practice.embibe.com", port: nil},
            payment: {url: "http://payment.embibe.com", port: nil},
            content: {url: "http://content.embibe.com", port: nil},          
            }

  end

  def generate_third_party_url
    urls = send("services_#{Rails.env}_urls")
    urls.map {|key,values| values.map {|k,v| define_method("#{key}_host_service_#{k}") { v }}}
  end

end
