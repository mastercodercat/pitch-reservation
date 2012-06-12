# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  helper_method :current_user
  helper_method :cart

  before_filter RubyCAS::Filter
  before_filter :first_run
  before_filter :first_time_user
  before_filter :cart
  before_filter :set_view_mode

  def current_user
    @current_user ||= User.find_by_login(session[:cas_user])
  end

  #-------- before_filter methods --------
  def first_run
    if Category.count == 0
      Category.create(:name => "Accessories")
    end
  end

  def first_time_user
    if current_user.nil?
      flash[:notice] = "Hey there! Since this is your first time making a reservation, we'll
        need you to supply us with some basic contact information."
      redirect_to new_user_path
    end
  end

  def cart
    if session[:cart]
      session[:cart]
      # binding.pry
    else
      session[:cart]= Cart.new
      session[:cart].set_reserver_id(current_user.id)
      binding.pry
    end
    # session[:cart].valid?
    #     binding.pry
  end

  def set_view_mode #(Analogous to department_chooser in shifts)
    if (params[:a_mode] && current_user.is_admin)
      current_user.update_attribute(:adminmode, 1)
	    current_user.update_attribute(:checkoutpersonmode, 0)
	    current_user.update_attribute(:normalusermode, 0)
	    current_user.update_attribute(:bannedmode, 0)
      flash[:notice] = "Viewing as Admin"
      redirect_to :action => "index" and return
    end
    if (params[:c_mode] && current_user.is_admin)
      current_user.update_attribute(:adminmode, 0)
	    current_user.update_attribute(:checkoutpersonmode, 1)
	    current_user.update_attribute(:normalusermode, 0)
	    current_user.update_attribute(:bannedmode, 0)
      flash[:notice] = "Viewing as Checkout Person"
      redirect_to :action => "index" and return
    end
    if (params[:n_mode] && current_user.is_admin)
	    current_user.update_attribute(:adminmode, 0)
	    current_user.update_attribute(:checkoutpersonmode, 0)
	    current_user.update_attribute(:normalusermode, 1)
	    current_user.update_attribute(:bannedmode, 0)
      flash[:notice] = "Viewing as Normal User"
      redirect_to :action => "index" and return
    end
    if (params[:b_mode] && current_user.is_admin)
	    current_user.update_attribute(:adminmode, 0)
      current_user.update_attribute(:checkoutpersonmode, 0)
	    current_user.update_attribute(:normalusermode, 0)
      current_user.update_attribute(:bannedmode, 1)
      flash[:notice] = "Viewing as Banned User"
      redirect_to :action => "index" and return
    end
  end
  #-------- end before_filter methods --------

  def update_cart
    session[:cart].set_start_date(Date.civil(params[:cart][:"start_date(1i)"].to_i,params[:cart][:"start_date(2i)"].to_i,params[:cart][:"start_date(3i)"].to_i))
    session[:cart].set_due_date(Date.civil(params[:cart][:"due_date(1i)"].to_i,params[:cart][:"due_date(2i)"].to_i,params[:cart][:"due_date(3i)"].to_i))
    flash[:notice] = "Cart dates updated."
    binding.pry
    redirect_to root_path
  end

  def empty_cart
    session[:cart] = Cart.new
    flash[:notice] = "Cart emptied."
    redirect_to root_path
  end

  def logout
    @current_user = nil
    RubyCAS::Filter.logout(self)
  end

  def require_admin(new_path=root_path)
    restricted_redirect_to(new_path) unless current_user.is_admin_in_adminmode?
  end

  def require_checkout_person(new_path=root_path)
    restricted_redirect_to(new_path) unless current_user.can_checkout?
  end

  def require_login
    if current_user.nil?
      flash[:error] = "Sorry, that action requires you to log in."
      redirect_to root_path
    end
  end

  def require_user(user, new_path=root_path)
    restricted_redirect_to(new_path) unless current_user == user or current_user.is_admin_in_adminmode?
  end

  def require_user_or_checkout_person(user, new_path=root_path)
    restricted_redirect_to(new_path) unless current_user == user or current_user.can_checkout?
  end

  def restricted_redirect_to(new_path=root_path)
    flash[:error] = "Sorry, that action or page is restricted."
    redirect_to new_path
  end

  def deactivate
    if (current_user.is_admin)
      @objects_class2 = params[:controller].singularize.titleize.delete(' ').constantize.find(params[:id]) #Finds the current model (User, EM, EO, Category)
      if (params[:controller] != "users") #Search for children is not necessary if we are altering users.
        deactivateChildren(@objects_class2)
      end
      @objects_class2.destroy #Deactivate the model you had originally intended to deactivate
      flash[:notice] = "Successfully deactivated " + params[:controller].singularize.titleize + ". Any child objects have been deactivated as well."
    else
      flash[:notice] = "Only administrators can do that!"
    end
    redirect_to request.referer   # Or use redirect_to(back). 
 end

  def activate
    if (current_user.is_admin)
      @model_to_activate = params[:controller].singularize.titleize.delete(' ').constantize.find(params[:id]) #Finds the current model (User, EM, EO, Category)
      if (params[:controller] != "users") #Search for parents is not necessary if we are altering users.
        activateParents(@model_to_activate)
      end
      @model_to_activate.revive #Activate the model you had originally intended to activate
      flash[:notice] = "Successfully reactivated " + params[:controller].singularize.titleize + ". Any parent objects have been reactivated as well."
    else
      flash[:notice] = "Only administrators can do that!"
    end   
    redirect_to request.referer  # Or use redirect_to(back)
  end

end
