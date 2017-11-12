# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171112194854) do

  create_table "admins", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "name"
    t.string "nickname"
    t.string "image"
    t.string "email"
    t.text "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_admins_on_confirmation_token", unique: true
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_admins_on_uid_and_provider", unique: true
  end

  create_table "answers", force: :cascade do |t|
    t.string "value"
    t.integer "question_id"
    t.integer "survey_id"
    t.integer "applicant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applicant_id"], name: "index_answers_on_applicant_id"
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["survey_id"], name: "index_answers_on_survey_id"
  end

  create_table "applicants", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "name"
    t.string "nickname"
    t.string "image"
    t.string "email"
    t.text "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.index ["confirmation_token"], name: "index_applicants_on_confirmation_token", unique: true
    t.index ["email"], name: "index_applicants_on_email", unique: true
    t.index ["reset_password_token"], name: "index_applicants_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_applicants_on_uid_and_provider", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.integer "applicant_id"
    t.integer "answer_id"
    t.string "file_uid"
    t.string "file_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_id"], name: "index_attachments_on_answer_id"
    t.index ["applicant_id"], name: "index_attachments_on_applicant_id"
  end

  create_table "questions", force: :cascade do |t|
    t.string "content"
    t.integer "survey_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "options"
    t.index ["survey_id"], name: "index_questions_on_survey_id"
  end

  create_table "surveys", force: :cascade do |t|
    t.string "name"
    t.boolean "approved", default: false
    t.integer "applicant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applicant_id"], name: "index_surveys_on_applicant_id"
  end

end
