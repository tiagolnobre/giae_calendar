class FinalEvaluation < ApplicationRecord
  belongs_to :school_year

  validates :school_year_id, uniqueness: true
end
