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
        @hold_list = [Reservation.upcoming].delete_if{|a| a.empty?}
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
          unless AppConfig.first.reservation_confirmation_email_active?
            UserMailer.reservation_confirmation(complete_reservation).deliver
          end
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
  
  def update # for editing reservations; not for checkout or check-in
    @reservation = Reservation.find(params[:id])
    
    # adjust dates to match intended input of Month / Day / Year
    start = Date.strptime(params[:reservation][:start_date],'%m/%d/%Y')
    due = Date.strptime(params[:reservation][:due_date],'%m/%d/%Y')
    
    # make sure dates are valid
    if due < start
      flash[:error] = 'Due date must be after the start date.'
      redirect_to :back and return
    end
    
    # update attributes
    @reservation.reserver_id = params[:reservation][:reserver_id]
    @reservation.start_date = start
    @reservation.due_date = due
    @reservation.notes = params[:reservation][:notes]
    
    # save changes to database
    @reservation.save

    # flash success and exit
    flash[:notice] = "Successfully edited reservation."
    redirect_to @reservation
  end

  def checkout
    error_msgs = ""
    reservations_to_be_checked_out = []
    
    # throw all the reservations that are being checked out into an array
    params[:reservations].each do |reservation_id, reservation_hash|
        if reservation_hash[:equipment_object_id] != ('' or NIL) then #update attributes for all equipment that is checked off
          r = Reservation.find(reservation_id)
          r.checkout_handler = current_user
          r.checked_out = Time.now
          r.equipment_object = EquipmentObject.find(reservation_hash[:equipment_object_id])

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

          # put the data into the container we defined at the beginning of this action
          reservations_to_be_checked_out << r

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

      # make sure we're not checking out the same object in more than one reservation
      if !reservations_to_be_checked_out.first.checkout_object_uniqueness(reservations_to_be_checked_out) # if objects not unique, flash error
        flash[:error] = "The same equipment item cannot be simultaneously checked out in multiple reservations."
        redirect_to :back and return
      end
      
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
  
  def checkin

    reservations_to_be_checked_in = []
    
    params[:reservations].each do |reservation_id, reservation_hash|
      if reservation_hash[:checkin?] == "1" then # update attributes for all equipment that is checked off
        r = Reservation.find(reservation_id)
        r.checkin_handler = current_user
        r.checked_in = Time.now

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

        # put the data into the container we defined at the beginning of this action
        reservations_to_be_checked_in << r
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
  
  def check_out # initializer
    @user = User.find(params[:user_id])
    @user_current_checkouts = Reservation.due_for_checkout(@user)
  end

  def check_in # initializer
    @user =  User.find(params[:user_id])
    @check_in_set = Reservation.due_for_checkin(@user)
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
    parameters[:term] = parameters[:term].downcase
    users=User.select("nickname, first_name, last_name,login, id, deleted_at").reject {|user| ! user.deleted_at.nil?}
    @search_result = []
    users.each do |user|
        if user.login.downcase.include?(parameters[:term]) ||
          user.name.downcase.include?(parameters[:term]) ||
          [user.first_name.downcase, user.last_name.downcase].join(" ").include?(parameters[:term])
          @search_result << user
        end
      end
      users = @search_result
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
