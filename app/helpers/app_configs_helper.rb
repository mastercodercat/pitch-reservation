# frozen_string_literal: true

module AppConfigsHelper
  def current_favicon_and_options
    if @app_configs.favicon.attached?
      @app_configs.favicon.variant(resize: '75x75')
    else
      'favicon.ico?v=2'
    end
  end
end
