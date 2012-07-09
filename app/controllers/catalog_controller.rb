class CatalogController < ApplicationController
  def index
    #push accessories to bottom by removing and reinserting
    #@equipment_models_by_category[Category.find_by_name("Accessories")] = @equipment_models_by_category.delete(Category.find_by_name("Accessories"))
  end

  def add_to_cart
    @equipment_model = EquipmentModel.find(params[:id])
    cart.add_equipment_model(@equipment_model)
    respond_to do |format|
      format.html{redirect_to root_path}
      format.js{render :action => "update_cart"}
    end
  rescue ActiveRecord::RecordNotFound
    logger.error("Attempt to add invalid equipment model #{params[:id]}")
    flash[:notice] = "Invalid equipment_model"
    redirect_to root_path
  end

  def remove_from_cart
    @equipment_model = EquipmentModel.find(params[:id])
    cart.remove_equipment_model(@equipment_model)
    respond_to do |format|
      format.html{redirect_to root_path}
      format.js{render :action => "update_cart"}
    end
  rescue ActiveRecord::RecordNotFound
    logger.error("Attempt to remove invalid equipment model #{params[:id]}")
    flash[:notice] = "Invalid equipment_model"
    redirect_to root_path
  end
  
  def update_user_per_cat_page
    session[:user_per_cat_page] = params[:user_cat_items_per_page] if !params[:user_cat_items_per_page].blank?
    respond_to do |format|
      format.html{redirect_to root_path}
      format.js{render :action => "cat_pagination"}
    end
  end

  def search
    @equipment_results = EquipmentModel.catalog_search(params[:query])
    @category_results = Category.catalog_search(params[:query])
    render 'search_results' and return
  end
  
end
