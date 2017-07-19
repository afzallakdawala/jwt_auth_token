ROUTES = {}
module RouterHelper

  def restClientUrl(url, payload = {})
    @_get_routers ||= get_routers
    _req = OpenStruct.new(ROUTES[url])
    payload = (JSON.parse(payload.to_json)).with_indifferent_access
    payload[:referer_service] = current_micro_service_name
    begin
      data = RestClient::Request.execute(method: _req.verb, url: _req.url, payload: payload, headers: { "#{jwt_header_name}" => jwt_header_token})
      data = {code: data.code, data: JSON.parse(data.body), headers: data.headers, cookies: data.cookies}
    rescue RestClient::Unauthorized, RestClient::Forbidden => err
      data = JSON.parse(err.response)
    rescue RestClient::ResourceNotFound => err
      data = {code: 404, error: "Url not found #{_req.url}" }
    end
    data
  end

  def get_routers
    Rails.application.routes.routes.map do |route|
      path = route.path.spec.to_s.gsub(/\(\.:format\)/, "").gsub(/:[a-zA-Z_]+/, "1")
      next if path.include?("rails")
      port = ":#{route.defaults[:port]}" if route.defaults[:port]
      complete_url = "#{route.defaults[:host]}#{port}#{path}"
      verb = %W{ GET POST PUT PATCH DELETE }.grep(route.verb).first.downcase.to_sym rescue nil
      route_name = route.defaults[:controller].gsub("/", "_") rescue route.name
      alias_should_be = route.defaults[:alias_should_be]
      final_key = "#{alias_should_be}_#{route_name}_#{verb}_url"
      ROUTES[final_key] = { path: path, verb: verb, url: complete_url}.merge(route.defaults)
    end
    ROUTES.delete(ROUTES.first.first)
  end

  def export_urls_csv
    get_routers
    CSV.open("tmp/route_list_#{Rails.env}.csv", 'w') do |csv|
      csv << [ROUTES.first[1].keys.map(&:to_s).unshift("alias") << ["development_url", "production_url"]].flatten
      ROUTES.each do |key, values|
        next if key.include?("rails") || key.include?("__url")
        dev_url = "#{current_service_host_service_url}:#{current_service_host_service_port}#{values.values[2]}"
        prod_url = "#{prod_domain}#{values.values[2]}"
        csv << values.values.map(&:to_s).unshift(key) + [dev_url] + [prod_url]
      end    
    end
  end

  def prod_domain
    "#{current_micro_service_name.split('_')[0]}.embibe.com"
  end

  def current_service_host_service_url
    eval("#{current_micro_service_name.split('_')[0]}_host_service_url")
  end

  def current_service_host_service_port
    eval("#{current_micro_service_name.split('_')[0]}_host_service_port")
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
