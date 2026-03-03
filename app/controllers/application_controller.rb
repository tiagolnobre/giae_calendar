# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  include Authentication

  before_action :authenticate_user!
end
