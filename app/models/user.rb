require 'net/ldap'

class User < ActiveRecord::Base
  has_many :reservations, :foreign_key => 'reserver_id'
  nilify_blanks :only => [:deleted_at] 

  attr_accessible :login, :first_name, :last_name, :nickname, :phone, :email,
                  :affiliation, :is_banned, :is_checkout_person, :is_admin,
                  :adminmode, :checkoutpersonmode, :normalusermode, :bannedmode, :deleted_at
  
  validates :first_name, 
            :last_name, 
            :affiliation, :presence => true
  validates :phone,       :presence    => true,
                          :format      => { :with => /\A\S[0-9\+\/\(\)\s\-]*\z/i },
                          :length      => { :minimum => 10 }
  validates :email,       :presence    => true,
                          :format      => { :with => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i }
  validates :nickname,    :format      => { :with => /^[^0-9`!@#\$%\^&*+_=]+$/ },
                          :allow_blank => true
  
  def name
     [((nickname.nil? || nickname.length == 0) ? first_name : nickname), last_name].join(" ")
  end
  
  def can_checkout?
    self.is_checkout_person? || self.is_admin_in_adminmode? || self.is_admin_in_checkoutpersonmode?
  end

  def is_admin_in_adminmode?
    is_admin? && adminmode?
  end

  def is_admin_in_checkoutpersonmode?
    is_admin? && checkoutpersonmode?
  end

  def is_admin_in_bannedmode?
    is_admin? && bannedmode?
  end
  
  def equipment_objects
    self.reservations.collect{ |r| r.equipment_objects }.flatten
  end

  # Returns array of the checked out equipment models and their counts for the user
  def checked_out_models
     # Make array of model ids of checked out equipment objects
    model_ids = self.reservations.collect do |r|
      if (!r.checked_out.nil? && r.checked_in.nil?) # i.e. if checked out but not checked in yet
        r.equipment_model_id
      end        
    end

    # Remove nils, count the number of unique model ids, store counts in a sub hash,
    # and finally sort by model_id
    model_ids.compact.inject(Hash.new(0)) { |h,x| h[x] += 1; h }.sort
  end
  
  def self.search_ldap(login)
    ldap = Net::LDAP.new(:host => "directory.yale.edu", :port => 389)
    filter = Net::LDAP::Filter.eq("uid", login)
    attrs = ["givenname", "sn", "eduPersonNickname", "telephoneNumber", "uid",
             "mail", "collegename", "curriculumshortname", "college", "class"]
    result = ldap.search(:base => "ou=People,o=yale.edu", :filter => filter, :attributes => attrs)
    unless result.empty?
    return { :first_name  => result[0][:givenname][0],
             :last_name   => result[0][:sn][0],
             :nickname    => result[0][:eduPersonNickname][0],
             # :phone     => result[0][:telephoneNumber][0],
             # Above line removed because the phone number in the Yale phonebook is always wrong
             :login       => result[0][:uid][0],
             :email       => result[0][:mail][0],
             :affiliation => [result[0][:curriculumshortname],
                              result[0][:college],
                              result[0][:class]].select{ |s| s.length > 0 }.join(" ") }
    end
  end

  def self.select_options
    self.find(:all, :order => 'last_name ASC').collect{ |item| ["#{item.last_name}, #{item.first_name}", item.id] }
  end
  
  def render_name
     self.first_name + ' ' + self.last_name + ' ' + self.login
  end
end
