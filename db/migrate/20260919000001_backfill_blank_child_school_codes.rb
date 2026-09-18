class BackfillBlankChildSchoolCodes < ActiveRecord::Migration[8.1]
  def up
    # Some children were created with an empty giae_school_code (the form
    # allowed a blank value, and the old default only covered nil, not "").
    # Login sends escola:"" which GIAE rejects with 401. Backfill through the
    # model so the value is properly encrypted in the giae_school_code column.
    Child.find_each do |child|
      if child.giae_school_code.blank?
        child.update_columns(giae_school_code: Child::DEFAULT_SCHOOL_CODE)
      end
    end
  end

  def down
    # Intentional no-op: not reversible.
  end
end