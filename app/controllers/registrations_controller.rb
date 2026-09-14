# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false, only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.except(:giae_username, :giae_password))
    @child = @user.children.build(
      giae_username: params[:user]&.dig(:giae_username),
      giae_password: params[:user]&.dig(:giae_password)
    )

    ActiveRecord::Base.transaction do
      @user.save!
      @child.save!
    end

    sign_in(@user)
    switch_to_child!(@child)
    redirect_to calendar_path, notice: t("flash.account_created")
  rescue ActiveRecord::RecordInvalid
    @user.errors.merge!(@child.errors) if @child && @child.errors.any?
    render :new, status: :unprocessable_entity
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
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end