class Evaluation < ApplicationRecord
  belongs_to :school_year
  belongs_to :subject
  belongs_to :evaluation_type
end
