class Property < ApplicationRecord
  ALLOWED_CATEGORIES = ['アパート', '一戸建て', 'マンション'].freeze
  DETACHED_HOUSE = '一戸建て'.freeze

  validates :custom_unique_id, presence: true
  validates :name, presence: true
  validates :address, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES, message: "must be one of: #{ALLOWED_CATEGORIES.join(', ')}" }
  validate :room_number_required_unless_detached_house

  private

  def room_number_required_unless_detached_house
    # room_number is only allowed to be null when category is '一戸建て'
    if category != DETACHED_HOUSE && room_number.nil?
      errors.add(:room_number, "is required for #{category}")
    end
  end
end

