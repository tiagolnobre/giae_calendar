class SetDefaultSchoolCodeForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    User.where(giae_school_code: nil).update_all(giae_school_code: "161676")
  end

  def down
    # No-op - we don't want to remove the school codes
  end
end
