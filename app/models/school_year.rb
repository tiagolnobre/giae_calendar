class SchoolYear < ApplicationRecord
  belongs_to :user
  has_many :subjects, dependent: :destroy
  has_many :evaluation_types, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :final_evaluations, dependent: :destroy

  validates :label, presence: true
  validates :label, uniqueness: { scope: :user_id }

  def self.label_from_date(date)
    if date.month >= 9
      "#{date.year}/#{date.year + 1}"
    else
      "#{date.year - 1}/#{date.year}"
    end
  end
end
