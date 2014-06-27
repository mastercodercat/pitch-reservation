require 'spec_helper'

describe ReservationsController do

  ## Common setup
  render_views

  before(:all) do
    @app_config = FactoryGirl.create(:app_config)

    @user = FactoryGirl.create(:user)
    @banned = FactoryGirl.create(:banned)
    @checkout_person = FactoryGirl.create(:checkout_person)
    @admin = FactoryGirl.create(:admin)

    @reservation = FactoryGirl.create(:valid_reservation, reserver: @user)
  end

  after(:all) do
    User.delete_all
    AppConfig.delete_all
    Reservation.delete_all
    Category.delete_all
    EquipmentModel.delete_all
    EquipmentObject.delete_all
  end

  before(:each) do
    @cart = FactoryGirl.build(:cart, reserver_id: @user.id)

    @controller.stub(:first_time_user).and_return(nil)
    @controller.stub(:current_user).and_return(@user)
  end

  ## Shared examples
  shared_examples 'cannot access page' do
    it { response.should be_redirect }
    it { should set_the_flash }
  end

  shared_examples 'inaccessible by banned user' do
    before(:each) do
      banned = FactoryGirl.build(:banned)
      @controller.stub(:current_user).and_return(banned)
      Reservation.stub(:find).and_return(FactoryGirl.build_stubbed(:reservation, reserver: banned))
    end
    include_examples 'cannot access page'
  end

  ##### Public methods of ReservationsController with routes

  ## Standard
  # index (GET index / ), show (GET /:id), new (GET /new),
  # create (POST /create), edit (GET /:id/edit), update (PUT /:id),
  # destroy (DELETE /:id)

  ## Custom
  # manage (GET /manage/:user_id), current (GET /current/:user_id)
  # checkout (PUT '/reservations/checkout/:user_id'),
  # checkin (PUT '/reservations/check-in/:user_id'),
  # checkout_email (GET 'reservations/checkout_email'),
  # checkin_email (GET 'reservations/checkin_email'),
  # renew (PUT '/reservations/renew')

  ## ?
  # upcoming, autocomplete_user_last_name

  ##### CanCan authentication summary
  # -> banned users can't do anything
  # -> Patrons can show and new/create/destroy their own reservation
  #    (destroy if it hasn't been checked out), renew own
  #    (if it's checked out and not yet checked in)
  # -> Checkout Persons can:
  #     do everything Patrons can do
  #     read, create... but not destroy Reservation
  #         (unless it hasn't been checked out yet)
  #     update reservation, override reservation errors and checkout errors
  #     if respective AppConfig settings allow it
  # => Admins can:
  #     do everything



  describe '#index GET /reservations/' do
    # check params[:filter]
    # depending on admin status, default_filter changes
    # depending on admin status, source of reservations (all v. own) changes

    context 'when accessed by non-banned user' do
      subject { get :index }
      it { should be_success }
      it { should render_template(:index) }

      it 'populates @reservations_set with reservations with respect to params[filter]' do
        # Setup
        @filters = [:reserved, :checked_out, :overdue, :missed,
          :returned, :upcoming]
        @setup_res = []
        @filters.each do |f|
          res = FactoryGirl.build(:valid_reservation, f, reserver: @user)
          res.save(validate: false)
          @setup_res << res
        end

        # Assertion and expectation
        @filters.each do |f|
          get :index, f => true
          assigns(:reservations_set).uniq.sort.should eq([Reservation.send(f).uniq.sort])
        end
      end

      it 'passes @default as false if valid params[filter] is provided' do
        get :index, reserved: true
        expect(assigns(:default)).to eq(false)
      end

      it 'passes @default as true if valid params[filter] is not provided' do
        get :index
        expect(assigns(:default)).to eq(true)
      end

      it 'passes @default as true if invalid params[filter] is provided' do
        get :index, absurd_and_nonexistent: true
        expect(assigns(:default)).to eq(true)
      end

      context 'who is an admin' do
        before(:each) do
          @controller.stub(:current_user).and_return(@admin)
        end
        it 'uses :upcoming as default filter'
        xit 'takes all Reservations as source' do
          expect(assigns(:reservations_source)).to eq(Reservation)
        end
      end

      context 'who is not an admin' do
        before(:each) do
          @controller.stub(:current_user).and_return(@user)
        end
        it 'uses :reserved as the default filter'
        xit 'uses only reservations belonging to current user as source' do
          expect(assigns(:reservations_source)).to eq(@controller.current_user.reservations)
        end
      end
    end

    it_behaves_like 'inaccessible by banned user' do
      before { get :index }
    end
  end

  describe '#show GET /reservations/:id' do
    context 'when accessed by a non-banned user' do
      before(:each) do
        @controller.stub(:current_user).and_return(@user)
        Reservation.stub(:find).and_return(@reservation)
        get :show, id: 1
      end
      it { response.should be_success }
      it { should render_template(:show) }

      context 'who is an admin' do
        it 'should display own reservation'
        it 'should display anybody\'s reservation'
      end

      context 'who is not an admin' do
        it 'should display own reservation'
        it 'should not display someone else\'s reservation'
      end
    end

    it_behaves_like 'inaccessible by banned user' do
      before { get :show, id: 1 }
    end
  end

  describe '#new GET /reservations/new' do
    # unhappy paths: banned user, there is no reservation in the cart
    it_behaves_like 'inaccessible by banned user' do
      before { get :new }
    end

    context 'when accessed by a non-banned user' do
      before(:each) { @controller.stub(:current_user).and_return(@user) }

      context 'with an empty cart' do
        before(:each) do
          get :new
        end
        it { response.should be_redirect }
        it { should set_the_flash }
      end

      context 'with a non-empty cart' do
        before(:each) do
          get :new, nil, { cart: FactoryGirl.build(:cart_with_items, reserver_id: @user.id) }
        end

        it 'should display errors'
        it { should render_template(:new) }
      end
    end
  end

  describe '#create POST /reservations/create' do
    it_behaves_like 'inaccessible by banned user' do
      before { post :create }
    end

    context 'when accessed by non-banned user' do
      context 'with validation-failing items in Cart' do
        it 'does not affect database'
        it 'sets flash[:error]'
        it 'redirects to catalog_path'
      end

      context 'with validation-passing items in Cart' do
        it 'saves items into database'
        it 'empties the Cart'
        it 'sets flash[:notice]'
        it 'is a redirect'

        context 'and user can override errors' do
          it 'redirects to manage_reservations_for_user_path'
        end

        context 'and user cannot override errors' do
          it 'redirects to catalog_path'
        end
      end
    end
  end

  describe '#edit GET /reservations/:id/edit' do
    it_behaves_like 'inaccessible by banned user' do
      before { get :edit }
    end

    context 'when accessed by non-banned user' do
      context 'who owns the reservation / has permissions to alter others' do
        it 'assigns @reservation'
        it 'assigns @option_array'
        it 'renders template `edit`'
      end

      context 'who does not own the reservation and lacks credentials' do
        before(:each) { get 'edit' }
        it_behaves_like 'cannot access page'
      end
    end
  end

  describe '#update PUT /reservations/:id' do
    it_behaves_like 'inaccessible by banned user' do
      before { put :update }
    end
  end

  describe '#destroy DELETE /reservations/:id' do
    it_behaves_like 'inaccessible by banned user' do
      before { delete :destroy }
    end
  end

  describe '#manage GET /reservations/manage/:user_id' do
    it_behaves_like 'inaccessible by banned user' do
      before { get :manage }
    end
  end

  describe '#current GET /reservations/current/:user_id' do
    it_behaves_like 'inaccessible by banned user' do
      before { get :current, user_id: @banned.id }
    end
  end
end