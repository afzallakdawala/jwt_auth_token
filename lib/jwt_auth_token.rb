module JwtAuthToken
end
require 'jwt'
require 'rest-client'
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
  data = RestClient::Request.execute(method: _req.verb, url: _req.url, payload: payload, headers: { "#{header_name}" => header_token})
  {code: data.code, data: JSON.parse(data.body), headers: data.headers, cookies: data.cookies}
end

def get_routers
  Rails.application.routes.routes.map do |route|
    path = route.path.spec.to_s.gsub(/\(\.:format\)/, "").gsub(/:[a-zA-Z_]+/, "1")
    next if path.include?("rails")
    port = ":#{route.defaults[:port]}" if route.defaults[:port]
    complete_url = "#{route.defaults[:host]}#{port}#{path}"
    verb = %W{ GET POST PUT PATCH DELETE }.grep(route.verb).first.downcase.to_sym rescue nil
    ROUTES["#{route.name}_url"] = { path: path, verb: verb, url: complete_url}
  end
end

def services_development_urls
  @_services_development_urls ||= {user_host_service: {url: "http://localhost", port: 3000},
          mocktest_host_service: {url: "http://localhost", port: 3002},
          practice_host_service: {url: "http://localhost", port: 3001},
          payment_host_service: {url: "http://localhost", port: 3003},
          content_host_service: {url: "http://localhost", port: 3004},          
          }
end

def services_production_urls
  @_services_production_urls ||= {user_host_service: {url: "http://user.embibe.com", port: nil},
          mocktest_host_service: {url: "http://mocktest.embibe.com", port: nil},
          practice_host_service: {url: "http://practice.embibe.com", port: nil},
          payment_host_service: {url: "http://payment.embibe.com", port: nil},
          content_host_service: {url: "http://content.embibe.com", port: nil},          
          }

end

def generate_third_party_url
  urls = send("services_#{Rails.env}_urls")
  urls.map {|key,values| values.map {|k,v| define_method("#{key}_#{k}") { v }}}
end
generate_third_party_url


def required_organization
  @organization ||= Organization.find_by(namespace: params[:namespace], language: params[:language])
  render_error("Organization or Language not found", 404) if @organization.nil?
end

def render_error(msg, status)
  render json: {"error" => msg, :status => status}, :status => status
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
