# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def new
    if user_signed_in?
      redirect_to calendar_path
    end
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      sign_in(user)

      # Set remember me cookie if requested
      if params[:remember_me] == "1"
        remember_user(user)
      end

      redirect_to calendar_path, notice: t("flash.signed_in")
    else
      flash.now[:alert] = t("flash.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to sign_in_path, notice: t("flash.signed_out")
  end
end
