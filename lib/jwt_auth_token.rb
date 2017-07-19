module JwtAuthToken
end
require 'jwt'
require 'rest-client'
require 'csv'

def current_micro_service_name
  @_current_micro_service_name ||= Rails.configuration.database_configuration[Rails.env]['mongodb_logger']['application_name']  
end

def jwt_hmac_secret
  @_jwt_hmac_secret ||= Rails.application.secrets[:secret_key_base]
end

def jwt_algorithm
  @_jwt_algorithm ||= 'HS512'
end

def header_name
  @_header_name ||= "embibe-token"
end

def jwt_set_header(data)
  encoded_token = JWT.encode(data,jwt_hmac_secret,jwt_algorithm)
  response.set_header(header_name, encoded_token)
end

def authenticate_user?
  if is_valid_token?
    return true
  else
    render json: {"error" => "User Authentication Failed", :status => 401}, :status => 401 and return
  end
end

def current_user
  @_current_user ||= OpenStruct.new(@decoded_token) if is_valid_token?
end

def header_token
  @_header_token ||= request.headers[header_name] rescue nil
end

def is_valid_token?
  begin
    @decoded_token = JSON.parse(JWT.decode(header_token, jwt_hmac_secret, true, { :algorithm => jwt_algorithm })[0])
    return validate_keys
  rescue Exception => e
    return false
  end  
end

def validate_keys
  !!@_validate_keys ||= (@decoded_token.keys && ["id", "email"]).any?
end

ROUTES = {}
def restClientUrl(url, payload = {})
  @_get_routers ||= get_routers
  _req = OpenStruct.new(ROUTES[url])
  payload = (JSON.parse(payload.to_json)).with_indifferent_access
  payload[:referer_service] = current_micro_service_name
  begin
    data = RestClient::Request.execute(method: _req.verb, url: _req.url, payload: payload, headers: { "#{header_name}" => header_token})
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

#practice_v1_bundles_get_url

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
generate_third_party_url


def required_organization
  @organization ||= Organization.find_by(namespace: params[:namespace], language: params[:language])
  render_error("Organization or Language not found", 404) if @organization.nil?
end

def render_error(msg, status)
  render json: {:error => msg, :status => status}, :status => status
end

def redis_set(batch_set)
  batch_set.each {|key, value| d}
end

def redis_get(key)
  (JSON.parse($redis.get(key)) || {}) rescue {}
end

def redis_data(key, value)
  {key: key, value: value}
end

def redis_process
  redis_set(_batch_events)
end

def add_custom_params_to_logger
  Rails.logger.add_metadata(custom_meta_data_log) if Rails.logger.respond_to?(:add_metadata)  
end

def user_agent_meta_log
  ua = DeviceDetector.new(request.user_agent)
  device_info = [:name, :full_version, :user_agent, :os_name, :os_full_version, :device_name, :device_brand, :device_type, :known?, :bot?, :bot_name]
  info_data = {url: request.url, referer: request.referer}  
  ua.methods.select {|c| info_data[c] = ua.__send__(c) if device_info.include?(c) }
  info_data
end

def custom_params_meta_log
  {c_source: params[:C_source], c_id: params[:C_id]}
end

def common_params_meta_log
  {referer_service: params[:referer_service]}
end

def custom_meta_data_log
  user_meta_log.merge!(user_agent_meta_log).merge!(custom_params_meta_log).merge!(common_params_meta_log)
end

def user_meta_log
  return {} unless current_user
  user_meta_data = {}
  user_meta_data[:user_id] = current_user.id
end