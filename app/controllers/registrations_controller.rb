# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false, only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      sign_in(@user)
      redirect_to calendar_path, notice: t("flash.account_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(user_params)
      redirect_to calendar_path, notice: t("flash.account_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :giae_username, :giae_password)
  end
end
