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
