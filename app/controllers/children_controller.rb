# frozen_string_literal: true

class ChildrenController < ApplicationController
  before_action :authenticate_user!
  before_action :set_child, only: [ :edit, :update, :destroy ]

  def index
    @children = current_user.children.order(:id)
  end

  def new
    @child = Child.new(user: current_user)
  end

  def create
    @child = Child.new(child_params.merge(user: current_user))

    if @child.save
      switch_to_child!(@child)
      redirect_to children_path, notice: t("children.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @child.update(child_params)
      redirect_to children_path, notice: t("children.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @child.destroy
    @current_child = nil
    redirect_to children_path, notice: t("children.deleted")
  end

  def select
    child = current_user.children.find(params[:id])
    switch_to_child!(child)
    redirect_back fallback_location: calendar_path, notice: t("children.selected", name: child.display_name)
  end

  private

  def set_child
    @child = current_user.children.find(params[:id])
  end

  def child_params
    params.require(:child).permit(:giae_username, :giae_password, :giae_school_code)
  end
end