class SchoolYear < ApplicationRecord
  belongs_to :user
  belongs_to :child, optional: true

  before_validation :sync_user_id, on: :create

  has_many :subjects, dependent: :destroy
  has_many :evaluation_types, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :final_evaluations, dependent: :destroy

  validates :label, presence: true
  validates :label, uniqueness: { scope: :child_id }, if: -> { child_id.present? }

  def self.label_from_date(date)
    if date.month >= 9
      "#{date.year}/#{date.year + 1}"
    else
      "#{date.year - 1}/#{date.year}"
    end
  end

  private

  def sync_user_id
    self.user_id = child.user_id if child && child.user_id && user_id.nil?
  end
end