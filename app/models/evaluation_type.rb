class EvaluationType < ApplicationRecord
  belongs_to :school_year
  has_many :evaluations, dependent: :destroy

  validates :idtipoavaliacao, uniqueness: { scope: :school_year_id }
end
