module CommonHelper
  def current_micro_service_name
    @_current_micro_service_name ||= Rails.configuration.database_configuration[Rails.env]['mongodb_logger']['application_name']  
  end

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
end
