class EquipmentModel < ActiveRecord::Base
  serialize :checkout_procedures
  serialize :checkin_procedures
  belongs_to :category
  has_many :equipment_objects
  has_many :documents
  # has_and_belongs_to_many :reservations
  # has_many :equipment_models_reservations
  has_many :reservations

  #associates with itself for accessories/recommended related models
  has_many :accessories_equipment_models, :foreign_key => :equipment_model_id
  has_many :accessories, :through => :accessories_equipment_models

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :description
  validates_numericality_of :late_fee
  validates_numericality_of :replacement_fee
  validates_numericality_of :max_per_user, :allow_nil => true

  attr_accessible :name, :category_id, :description, :late_fee, :replacement_fee, :max_per_user, :document_attributes, :accessory_ids, :checkout_procedures, :checkin_procedures

  #inherits from category if not defined
  def maximum_per_user
    max_per_user || category.maximum_per_user
  end

  def self.select_options
    self.order('name ASC').collect{|item| [item.name, item.id]}
  end

  def document_attributes=(document_attributes)
    document_attributes.each do |attributes|
      documents.build(attributes)
    end
  end

  def formatted_description
    lines = self.description.split(/^/)

    nice_content = "<p>"
    lines.each do |line|
      if line.include? "<table>" or line.include? "<td>"
        nice_content += line
      else
        nice_content += line + "<br />"
      end
    end
    nice_content += "</p>"
  end

  def photos
    self.documents.images
  end

  def available?(date_range)
    overall_count = self.equipment_objects.size
    date_range.each do |date|
      available_on_date = available_count(date)
      overall_count = available_on_date if available_on_date < overall_count
      return false if overall_count == 0
    end
    overall_count
  end

  def available_count(date)
    # get the total number of objects of this kind
    # then subtract the total quantity currently checked out, reserved, or overdue
    # TODO: the system does not account for early checkouts.

    reserved_count = Reservation.where("checked_in IS NULL and checked_out IS NULL and equipment_model_id = ? and start_date <= ? and due_date >= ?", self.id, date.to_time.utc, date.to_time.utc).size
    overdue_count = Reservation.where("checked_in IS NULL and checked_out IS NOT NULL and equipment_model_id = ? and due_date <= ?", self.id, Date.today.to_time.utc).size

    self.equipment_objects.count - reserved_count - overdue_count
  end

  def available_object_select_options
    self.equipment_objects.select{|e| e.available?}.sort_by(&:name).collect{|item| "<option value=#{item.id}>#{item.name}</option>"}
  end
end

