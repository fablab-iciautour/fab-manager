# frozen_string_literal: true

# OfferDay provides a way for admins to extend the subscription of a member for free.
class OfferDay < ApplicationRecord
  include NotifyWith::NotificationAttachedObject

  has_many :invoices, as: :invoiced, dependent: :destroy
  belongs_to :subscription
end
