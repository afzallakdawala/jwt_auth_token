module JwtAuthToken
end
require 'jwt'
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

def is_valid_token?
  begin
    token = request.headers[header_name]
    @decoded_token = JSON.parse(JWT.decode(token, jwt_hmac_secret, true, { :algorithm => jwt_algorithm })[0])
    return validate_keys
  rescue Exception => e
    return false
  end  
end

def validate_keys
  !!@_validate_keys ||= (@decoded_token.keys && ["id", "email"]).any?
end