class Subject < ApplicationRecord
  belongs_to :school_year
  has_many :evaluations, dependent: :destroy

  validates :idmatriculadisciplina, uniqueness: { scope: :school_year_id }
end
