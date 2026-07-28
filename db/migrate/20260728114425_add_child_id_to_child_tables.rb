class AddChildIdToChildTables < ActiveRecord::Migration[8.1]
  TABLES = %w[meal_tickets meal_details saldo_records school_years giae_sessions notifications]

  def change
    TABLES.each do |table|
      add_column table, :child_id, :integer
    end

    add_index :meal_tickets, :child_id
    add_index :meal_details, :child_id
    add_index :saldo_records, :child_id
    add_index :school_years, :child_id
    add_index :giae_sessions, :child_id
    add_index :notifications, :child_id

    add_index :meal_tickets, [:child_id, :date], unique: true, where: "child_id IS NOT NULL"
    add_index :meal_details, [:child_id, :date], where: "child_id IS NOT NULL"
    add_index :saldo_records, [:child_id, :created_at]
    add_index :school_years, [:child_id, :label], unique: true, where: "child_id IS NOT NULL"
    add_index :giae_sessions, [:child_id, :status], where: "child_id IS NOT NULL"

    up_only do
      meal_tickets_backfill
      meal_details_backfill
      saldo_records_backfill
      school_years_backfill
      giae_sessions_backfill
      notifications_backfill
    end
  end

  private

  def meal_tickets_backfill
    MealTicket.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end

  def meal_details_backfill
    MealDetail.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end

  def saldo_records_backfill
    SaldoRecord.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end

  def school_years_backfill
    SchoolYear.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end

  def giae_sessions_backfill
    GiaeSession.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end

  def notifications_backfill
    Notification.where(child_id: nil).find_each do |record|
      child = Child.find_by(user_id: record.user_id)
      record.update_column(:child_id, child.id) if child
    end
  end
end
