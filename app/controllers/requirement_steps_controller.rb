class RequirementStepsController < ApplicationController

  before_filter :require_admin

  def index
    @requirementSteps = RequirementStep.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @requirements }
    end
  end

  def show
    @requirement = Requirement.find(RequirementStep.find(params[:id]).requirement)
    @requirementSteps = RequirementStep.order("position")

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @requirement }
    end
  end


  def new
    @requirementStep = RequirementStep.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @requirement }
    end
  end

  # GET /requirements/1/edit
  def edit
    @requirementStep = RequirementStep.find(params[:id])
  end

  # POST /requirements
  # POST /requirements.xml
  def create
    @requirement = Requirement.new(params[:requirement])
     respond_to do |format|
      if @requirement.save
        format.html { redirect_to(@requirement, :notice => 'Requirement was successfully created.') }
        format.xml  { render :xml => @requirement, :status => :created, :location => @requirement }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @requirement.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /requirements/1
  # PUT /requirements/1.xml
  def update
    @requirement = Requirement.find(params[:id])

    respond_to do |format|
      if @requirement.update_attributes(params[:requirement])
        format.html { redirect_to(@requirement, :notice => 'Requirement was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @requirement.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /requirements/1
  # DELETE /requirements/1.xml
  def destroy
    @requirement = Requirement.find(params[:id])
    @requirement.destroy(:force)

    respond_to do |format|
      format.html { redirect_to(requirements_url) }
      format.xml  { head :ok }
    end
  end
end
