# frozen_string_literal: true

# Export is a reference to a file asynchronously generated by the system and downloadable by the user
class Export < ApplicationRecord
  require 'fileutils'

  belongs_to :user

  validates :category, presence: true
  validates :export_type, presence: true
  validates :user, presence: true

  after_commit :generate_and_send_export, on: [:create]

  def file
    dir = "exports/#{category}/#{export_type}"

    # create directories if they doesn't exists (exports & type & id)
    FileUtils.mkdir_p dir
    "#{dir}/#{filename}"
  end

  def filename
    "#{export_type}-#{id}_#{created_at.strftime('%d%m%Y')}.#{extension}"
  end

  private

  def generate_and_send_export
    case category
    when 'statistics'
      StatisticsExportWorker.perform_async(id)
    when 'users'
      UsersExportWorker.perform_async(id)
    when 'availabilities'
      AvailabilitiesExportWorker.perform_async(id)
    when 'accounting'
      AccountingExportWorker.perform_async(id)
    else
      raise NoMethodError, "Unknown export service for #{category}/#{export_type}"
    end
  end
end
