class ReservationsController < ApplicationController
  before_filter :require_login, :only => [:index, :show]
  before_filter :require_checkout_person, :only => [:check_out, :check_in]

  def index
    if current_user.can_checkout?
      if params[:show_missed]
        @reservations_set = [Reservation.overdue, Reservation.checked_out, Reservation.reserved, Reservation.missed].delete_if{|a| a.empty?}
      elsif params[:show_returned]
        @reservations_set = [Reservation.overdue, Reservation.checked_out, Reservation.reserved, Reservation.returned].delete_if{|a| a.empty?} #remove empty arrays from set
      elsif params[:upcoming]
        @reservations_set = [Reservation.upcoming].delete_if{|a| a.empty?}
      else
        @reservations_set = [Reservation.overdue, Reservation.checked_out, Reservation.reserved].delete_if{|a| a.empty?}
      end
    else
      @reservations_set = [current_user.reservations.overdue, current_user.reservations.checked_out, current_user.reservations.reserved ].delete_if{|a| a.empty?}
    end
  end

  def show
    @reservation = Reservation.find(params[:id])
  end

  def show_all #Action called in _reservations_list partial view, allows checkout person to view all current reservations for one user
    @user = User.find(params[:user_id])
    @user_overdue_reservations_set = [Reservation.overdue_user_reservations(@user)].delete_if{|a| a.empty?}
    @user_checked_out_today_reservations_set = [Reservation.checked_out_today_user_reservations(@user)].delete_if{|a| a.empty?}
    @user_checked_out_previous_reservations_set = [Reservation.checked_out_previous_user_reservations(@user)].delete_if{|a| a.empty?}
    @user_reserved_reservations_set = [Reservation.reserved_user_reservations(@user)].delete_if{|a| a.empty?}
  end

  def new
    if cart.items.empty?
      flash[:error] = "You need to add items to your cart before making a reservation."
      redirect_to catalog_path
    else
      #this is used to initialize each reservation later
      @reservation = Reservation.new(start_date: cart.start_date, due_date: cart.due_date, reserver_id: cart.reserver_id)
    end
  end

  def create
    complete_reservation = []
    #using http://stackoverflow.com/questions/7233859/ruby-on-rails-updating-multiple-models-from-the-one-controller as inspiration
    respond_to do |format|
      Reservation.transaction do
        begin
          cart.items.each do |item|
            emodel = item.equipment_model
            item.quantity.times do |q|    # accounts for reserving multiple equipment objects of the same equipment model (mainly for admins)
              @reservation = Reservation.new(params[:reservation])
              @reservation.equipment_model =  emodel
              @reservation.save
              complete_reservation << @reservation
            end
          end
          session[:cart] = Cart.new
          UserMailer.reservation_confirmation(complete_reservation).deliver
          format.html {redirect_to catalog_path, :flash => {:notice => "Successfully created reservation. " } }
        rescue
          format.html {redirect_to catalog_path, :flash => {:error => "Oops, something went wrong with making your reservation."} }
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  def edit
    @reservation = Reservation.find(params[:id])
  end

# delete this code after 10 july 2012 if no issues
#  def update
#    error_msgs = ""
#    if params[:commit] == "Check out equipment"

#      reservations_to_be_checked_out = []
#      reservation_check_out_procedures_count = []
#      params[:reservations].each do |reservation_id, reservation_hash|
#        if reservation_hash[:checkout?] == "1" then #update attributes for all equipment that is checked off
#          r = Reservation.find(reservation_id)
#          r.checkout_handler = current_user
#          r.checked_out = Time.now
#          r.equipment_object = EquipmentObject.find(reservation_hash[:equipment_object_id])
#          reservations_to_be_checked_out << r
#          reservation_check_out_procedures_count << (reservation_hash[:checkout_procedures] || []).count #There is no editable "checkout procedures count" attribute for reservations. For now, I have these two arrays, and compare them in a hash to make sure that all checkout procedures are checked off
#        end
#      end

#      #All-encompassing checks, only need to be done once
#      if reservations_to_be_checked_out.first.nil? #Prevents the nil error from not selecting any reservations
#        flash[:error] = "No reservation selected!"
#        redirect_to :back and return
#      elsif Reservation.overdue_reservations?(reservations_to_be_checked_out.first.reserver) #Checks for any overdue equipment
#        error_msgs += "User has overdue equipment."
#      end

#      #Checks that must be iterated over each individual reservation
#      error_msgs += reservations_to_be_checked_out.first.check_out_permissions(reservations_to_be_checked_out, reservation_check_out_procedures_count) #This method checks the Category Max Per User, Equipment Model Max per User, and whether all the checkout procedures have been checked off
#      if !error_msgs.empty? #If any requirements are not met...
#        if current_user.is_admin_in_adminmode? #Admins can ignore them
#          error_msgs = " Admin Override: Equipment has been successfully checked out even though " + error_msgs
#        else #everyone else is redirected
#          flash[:error] = error_msgs
#          redirect_to :back and return
#        end
#      end
#      reservations_to_be_checked_out.each do |reservation| #updates to reservations are saved
#        reservation.save
#      end
#      flash[:notice] = error_msgs.empty? ? "Successfully checked out equipment!" : error_msgs #Allows admins to see all errors, but still checkout successfully
#      redirect_to :action => 'show' and return

#    elsif params[:commit] == "Check in equipment"

#      if params[:reservations].nil? #Prevents the nil error from not selecting any reservations
#        flash[:error] = "No reservation selected!"
#        redirect_to :back and return
#      end

#      reservations_to_be_checked_in = []
#      reservation_check_in_procedures_count = []
#      params[:reservations].each do |reservation_id, reservation_hash|
#        if reservation_hash[:checkin?] == "1"  then
#          r = Reservation.find(reservation_id)
#          r.checkin_handler = current_user
#          r.checked_in = Time.now
#          reservations_to_be_checked_in << r
#          reservation_check_in_procedures_count << (reservation_hash[:checkin_procedures] || []).count #Like above, accounting for check in procedures count using two arrays
#        else
#          flash[:error] = "You filled out check in procedures without selecting the reservation!" #Prevents the nil error from selecting checkout procedures, but no reservations.
#          redirect_to :back and return
#        end
#      end

#      error_msgs = reservations_to_be_checked_in.first.check_in_permissions(reservations_to_be_checked_in, reservation_check_in_procedures_count) #This method currently just counts the check in procedures to make sure they are all checked off
#      if !error_msgs.empty?
#        flash[:error] = error_msgs
#        redirect_to :back and return
#      else
#        reservations_to_be_checked_in.each do |reservation|
#          reservation.save
#        end
#        flash[:notice] = "Successfully checked in equipment!"
#        redirect_to :action => 'show' and return
#      end

#    elsif params[:commit] == "Submit" #For editing reservations
#      @reservation = Reservation.find(params[:id])
#      if @reservation.update_attributes(params[:reservation])
#        flash[:notice] = "Successfully edited reservation."
#        redirect_to @reservation
#      end
#    end
#  end
  
  def update # for editing reservations; not for checkout or check-in
    @reservation = Reservation.find(params[:id])
    if @reservation.update_attributes(params[:reservation])
      flash[:notice] = "Successfully edited reservation."
      redirect_to @reservation
    end
  end

  def checkout_by_user
    error_msgs = ""
    reservations_to_be_checked_out = []
#    reservation_check_out_procedures_count = [] # TODO delete? we're no longer counting
    
    # throw all the reservations that are being checked out into an array
    params[:reservations].each do |reservation_id, reservation_hash|
        if reservation_hash[:equipment_object_id] != ('' or NIL) then #update attributes for all equipment that is checked off
          r = Reservation.find(reservation_id)
          r.checkout_handler = current_user
          r.checked_out = Time.now
          r.equipment_object = EquipmentObject.find(reservation_hash[:equipment_object_id])
      # method start    
          # deal with checkout procedures
          procedures_not_done = '' # initialize
          r.equipment_model.checkout_procedures.each do |check|
            if reservation_hash[:checkout_procedures] == NIL # if none were checked, note that
              procedures_not_done += '* ' + check.step + '\n'
            elsif !reservation_hash[:checkout_procedures].keys.include?(check.id.to_s) # if you didn't check it of, add to string
              procedures_not_done += '* ' + check.step + '\n'
            end
          end

          # add procedures_not_done to r.notes so admin gets the errors
          # if no notes and some procedures not done
          if (reservation_hash[:notes] == ('' or NIL)) and (!procedures_not_done.blank?)
            r.notes = 'The following checkout procedures were not performed:\n' + procedures_not_done
          elsif procedures_not_done.blank? # if all procedures were done
            r.notes = reservation_hash[:notes]
          else # if there is a note and some checkout procedures were not done
            r.notes = reservation_hash[:notes] + '\n\nThe following checkout procedures were not performed:\n' + procedures_not_done
          end
       # method end
          # put the data into the container we defined at the beginning of this action
          reservations_to_be_checked_out << r # david if you name the function this change this name
          
          # TODO delete this next line? we're now recording which aren't done
#          reservation_check_out_procedures_count << (reservation_hash[:checkout_procedures] || []).count #There is no editable "checkout procedures count" attribute for reservations. For now, I have these two arrays, and compare them in a hash to make sure that all checkout procedures are checked off
        end
      end
      
  # done with throwing things into the array
      
      #All-encompassing checks, only need to be done once
      if reservations_to_be_checked_out.first.nil? #Prevents the nil error from not selecting any reservations
        flash[:error] = "No reservation selected."
        redirect_to :back and return
      # move method to user model TODO
      elsif Reservation.overdue_reservations?(reservations_to_be_checked_out.first.reserver) #Checks for any overdue equipment
        error_msgs += "User has overdue equipment."
      end
      
      #Checks that must be iterated over each individual reservation
      # TODO what does this line do? it shouldn't need to be run again since done when finalizing reservation, talk with erin
#      error_msgs += reservations_to_be_checked_out.first.check_out_permissions(reservations_to_be_checked_out, reservation_check_out_procedures_count) #This method checks the Category Max Per User, Equipment Model Max per User, and whether all the checkout procedures have been checked off
      
      # act on the errors
      if !error_msgs.empty? # If any requirements are not met...
        if current_user.is_admin_in_adminmode? # Admins can ignore them
          error_msgs = " Admin Override: Equipment has been successfully checked out even though " + error_msgs
        else # everyone else is redirected
          flash[:error] = error_msgs
          redirect_to :back and return
        end
      end
      
      # transaction this process ^downarrow
      
      # save reservations
      reservations_to_be_checked_out.each do |reservation| # updates to reservations are saved
        reservation.save # save!
      end
      
      # flash 'save successful' messages
      flash[:notice] = error_msgs.empty? ? "Successfully checked out equipment!" : error_msgs #Allows admins to see all errors, but still checkout successfully
      
      # now exit
      redirect_to show_all_reservations_for_user_path and return
  end
  
  def check_in_by_user

    reservations_to_be_checked_in = []
#    reservation_check_in_procedures_count = [] # delete?
    
    params[:reservations].each do |reservation_id, reservation_hash|
      if reservation_hash[:checkin?] == "1" then # update attributes for all equipment that is checked off
        r = Reservation.find(reservation_id)
        r.checkin_handler = current_user
        r.checked_in = Time.now
    # method start    
        # deal with checkout procedures
        procedures_not_done = '' # initialize
        r.equipment_model.checkin_procedures.each do |check|
          if reservation_hash[:checkin_procedures] == NIL # if none were checked, note that
            procedures_not_done += '* ' + check.step + '\n'
          elsif !reservation_hash[:checkin_procedures].keys.include?(check.id.to_s) # if you didn't check it of, add to string
            procedures_not_done += '* ' + check.step + '\n'
          end
        end

        # add procedures_not_done to r.notes so admin gets the errors
        # if no notes and some procedures not done
        if (reservation_hash[:notes] == ('' or NIL)) and (!procedures_not_done.blank?)
          r.notes = '\n\nThe following check-in procedures were not performed:\n' + procedures_not_done
        elsif procedures_not_done.blank? # if all procedures were done
          r.notes = '\n\n' + reservation_hash[:notes] # add blankline because there may well have been previous notes
        else # if there is a note and some checkout procedures were not done
          r.notes = '\n\n' + reservation_hash[:notes] + '\n\nThe following check-in procedures were not performed:\n' + procedures_not_done
        end
     # method end
        # put the data into the container we defined at the beginning of this action
        reservations_to_be_checked_in << r # david if you name the function this change this name
      end
    end
  
    # flash errors
    if reservations_to_be_checked_in.empty?
      flash[:error] = "No reservation selected!"
      redirect_to :back and return
    end
  
    # save the reservations
    reservations_to_be_checked_in.each do |reservation|
      reservation.save
    end
    
    # exit
    flash[:notice] = "Successfully checked in equipment!"
    redirect_to show_all_reservations_for_user_path and return
  end

  def destroy
    @reservation = Reservation.find(params[:id])
    require_user_or_checkout_person(@reservation.reserver)
    @reservation.destroy
    flash[:notice] = "Successfully destroyed reservation."
    redirect_to reservations_url
  end
  
  def upcoming
    @reservations_set = [Reservation.upcoming].delete_if{|a| a.empty?}
  end

  def check_out # delete?
    @user = User.find(params[:user_id])
    @check_out_set = Reservation.due_for_checkout(@user)
  end
  
  def check_out_by_user
    @user = User.find(params[:user_id])
    @user_current_checkouts = Reservation.due_for_checkout(@user)
  end

  def check_out_single # delete?
    @reservation = Reservation.find(params[:id])
  end

  def check_in
    @user =  User.find(params[:user_id])
    @check_in_set = Reservation.due_for_checkin(@user)
  end

  def check_in_single # delete?
    @reservation =  Reservation.find(params[:id])
  end

  #two paths to create receipt emails for checking in and checking out items.
  def checkout_email
    @reservation =  Reservation.find(params[:id])
    if UserMailer.checkout_receipt(@reservation).deliver
      redirect_to :back
      flash[:notice] = "Successfully delivered receipt email."
    else 
      redirect_to @reservation
      flash[:error] = "Unable to deliver receipt email. Please contact administrator for more support. "
    end
  end
  
  def checkin_email
    @reservation =  Reservation.find(params[:id])
    if UserMailer.checkin_receipt(@reservation).deliver
      redirect_to :back
      flash[:notice] = "Successfully delivered receipt email."
    else 
      redirect_to @reservation
      flash[:error] = "Unable to deliver receipt email. Please contact administrator for more support. "
    end
  end

  autocomplete :user, :last_name, :extra_data => [:first_name, :login], :display_value => :render_name
  
  def get_autocomplete_items(parameters)
    items = User.select("first_name, last_name, login, id").where(["CONCAT_WS(' ', first_name, last_name, login) LIKE ?", "%#{parameters[:term]}%"])
  end

  def renew
    @reservation = Reservation.find(params[:id])
    @reservation.due_date += @reservation.max_renewal_length_available.days
    if @reservation.times_renewed == NIL # this check can be removed? just run the else now?
      @reservation.times_renewed = 1
    else
      @reservation.times_renewed += 1
    end

    if !@reservation.save
      redirect_to @reservation
      flash[:error] = "Unable to update reservation dates. Please contact us for support."
    end
    respond_to do |format|
      format.html{redirect_to root_path}
      format.js{render :action => "renew_box"}
    end
  end

end

