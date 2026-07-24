class EvaluationType < ApplicationRecord
  belongs_to :school_year
  has_many :evaluations, dependent: :destroy
end
