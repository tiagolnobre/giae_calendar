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
      redirect_to calendar_path, notice: "Signed in successfully."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to sign_in_path, notice: "Signed out successfully."
  end
end
