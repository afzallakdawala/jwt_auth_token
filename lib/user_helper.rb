module UserHelper  

  def current_user
    @_current_user ||= OpenStruct.new(@decoded_token) if is_jwt_valid_token?
  end

  def authenticate_user?
    if is_jwt_valid_token?
      return true
    else
      render json: {"error" => "User Authentication Failed", :status => 401}, :status => 401 and return
    end
  end

end