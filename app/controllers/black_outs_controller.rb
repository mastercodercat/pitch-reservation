class BlackOutsController < ApplicationController
  # GET /black_outs
  # GET /black_outs.json
  def index
    @black_outs = BlackOut.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @black_outs }
    end
  end

  # GET /black_outs/1
  # GET /black_outs/1.json
  def show
    @black_out = BlackOut.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @black_out }
    end
  end

  # GET /black_outs/new
  # GET /black_outs/new.json
  def new
    @black_out = BlackOut.new
    @black_out[:start_date] = Date.today
    @black_out[:end_date] = Date.today

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @black_out }
    end
  end

  # GET /black_outs/1/edit
  def edit
    @black_out = BlackOut.find(params[:id])
  end

  # POST /black_outs
  # POST /black_outs.json
  def create
    params[:black_out][:start_date] = Date.strptime(params[:black_out][:start_date],'%m/%d/%Y')
    params[:black_out][:end_date] = Date.strptime(params[:black_out][:end_date],'%m/%d/%Y')
    params[:black_out][:created_by] = current_user[:id]
    @black_out = BlackOut.new(params[:black_out])

    respond_to do |format|
      if @black_out.save

        format.html { redirect_to @black_out, notice: 'Black out was successfully created.' }
        format.json { render json: @black_out, status: :created, location: @black_out }
      else
        format.html { render action: "new" }
        format.json { render json: @black_out.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /black_outs/1
  # PUT /black_outs/1.json
  def update
    @black_out = BlackOut.find(params[:id])

    params[:black_out][:start_date] = Date.strptime(params[:black_out][:start_date],'%m/%d/%Y')
    params[:black_out][:end_date] = Date.strptime(params[:black_out][:end_date],'%m/%d/%Y')
    params[:black_out][:created_by] = current_user[:id]

    respond_to do |format|
      if @black_out.update_attributes(params[:black_out])
        format.html { redirect_to @black_out, notice: 'Black out was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @black_out.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /black_outs/1
  # DELETE /black_outs/1.json
  def destroy
    @black_out = BlackOut.find(params[:id])
    @black_out.destroy

    respond_to do |format|
      format.html { redirect_to black_outs_url }
      format.json { head :no_content }
    end
  end
end
