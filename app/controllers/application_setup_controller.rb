class ApplicationSetupController < ApplicationController
  skip_filter :first_time_user
  skip_filter :app_setup
  
 # before_filter :redirect_if_not_first_run
  before_filter :initialize_app_configs
  before_filter :new_admin_user

  def new_admin_user
    flash[:notice] = "Welcome to Reservations! Create your user and you will be guided 
                      through a setup to get your application up and running."
    if current_user and current_user.is_admin_in_adminmode?
       @user = User.new
     else
       @user = User.new(User.search_ldap(session[:cas_user]))
       @user.login = session[:cas_user] #default to current login
     end
   end

  def create_admin_user
    @user = User.new(params[:user])
    @user.login = session[:cas_user] unless current_user and (current_user.is_admin_in_adminmode? or current_user.is_admin_in_checkoutpersonmode? or current_user.is_checkout_person?)
    @user.is_admin = true
    if @user.save
      flash[:notice] = "Successfully created Admin."
      redirect_to new_app_configs_path
    else
      render :action => 'new_admin_user'
    end
  end
  
  def initialize_app_configs
     if @app_configs.nil?
       AppConfig.create!({ :site_title => "Reservations",
                           :admin_email => "admin@admin.admin",
                           :department_name => "School of Art Digital Technology Office",
                           :contact_link_text => "Contact Us", 
                           :contact_link_location => "mailto:contact.us@change.com", 
                           :home_link_text => "Home", 
                           :home_link_location => "http://clc.yale.edu", 
                           :default_per_cat_page => 20,
                           :upcoming_checkin_email_body => "Dear @user@,
                           Please remember to return the equipment you borrowed from us:
 
                           @equipment_list@

                           If the equipment is returned after 4 pm on @return_date@ you will be charged a late fee or replacement fee. Repeated late returns will result in the privilege to make further reservations for the rest of the term to be revoked.

                           Thank you,
                           @department_name@",
                           :overdue_checkout_email_body => "Dear @user@,
                           You have missed a scheduled equipment checkout, so your equipment may be released and checked out to other students.

                           Thank you,
                           @department_name@",
                           :overdue_checkin_email_body => "Dear @user@,
                           You were supposed to return the equipment you borrowed from us on @return_date@ but because you have failed to do so, you will be charged @late_fee@ / day until the equipment is returned. Failure to return equipment will result in replacement fees and revocation of borrowing privileges.

                           Thank you,
                           @department_name@"
                           })
     end
   end
   
   def new_app_configs
     flash[:notice] = "Edit your application settings here."
     @app_configs = AppConfig.first
   end
   
   def create_app_configs
     @app_configs = AppConfig.first   
      if @app_configs.update_attributes(params[:app_config])
        flash[:notice] = "Application settings updated successfully."
        redirect_to root_path
      else
        flash[:error] = "Error saving application settings."
        redirect_to :action => 'edit'
      end
  end
  
  private
    def redirect_if_not_first_run
      if User.first
        flash[:error] = "The setup wizard can only be run on first launch."
        redirect_to root_path
      end
    end  
end
