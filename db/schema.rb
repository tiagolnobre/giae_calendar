# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_12_220000) do
  create_table "giae_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "error_message"
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "lock_key"
    t.datetime "locked_at"
    t.string "locked_by"
    t.datetime "obtained_at"
    t.datetime "refreshed_at"
    t.text "session_cookie_ciphertext"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_giae_sessions_on_expires_at"
    t.index ["lock_key"], name: "index_giae_sessions_on_lock_key", unique: true, where: "lock_key IS NOT NULL"
    t.index ["updated_at"], name: "index_giae_sessions_on_updated_at"
    t.index ["user_id", "status"], name: "index_giae_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_giae_sessions_on_user_id"
  end

  create_table "meal_details", force: :cascade do |t|
    t.string "bread"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "dessert"
    t.string "main_dish"
    t.string "period", null: false
    t.string "soup"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vegetables"
    t.index ["user_id", "date"], name: "index_meal_details_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_meal_details_on_user_id"
  end

  create_table "meal_tickets", force: :cascade do |t|
    t.boolean "bought"
    t.datetime "created_at", null: false
    t.date "date"
    t.string "dish_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["dish_type"], name: "index_meal_tickets_on_dish_type"
    t.index ["user_id", "date"], name: "index_meal_tickets_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_meal_tickets_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "notifiable_id"
    t.string "notifiable_type"
    t.integer "notification_type", default: 0
    t.datetime "read_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.text "auth"
    t.datetime "created_at", null: false
    t.text "endpoint"
    t.text "p256dh"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "saldo_records", force: :cascade do |t|
    t.integer "cents", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_saldo_records_on_user_id_and_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.boolean "email_notifications_enabled", default: true
    t.string "giae_password"
    t.text "giae_password_ciphertext"
    t.string "giae_school_code"
    t.string "giae_username"
    t.text "giae_username_ciphertext"
    t.boolean "in_app_notifications_enabled", default: true
    t.datetime "last_refreshed_at"
    t.string "password_digest", default: "", null: false
    t.datetime "remember_created_at"
    t.string "remember_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "giae_sessions", "users"
  add_foreign_key "meal_details", "users"
  add_foreign_key "meal_tickets", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "saldo_records", "users"
end
