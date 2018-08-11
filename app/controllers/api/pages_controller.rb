class API::PagesController < API::ApiController
  before_action :authenticate_user!, except: [:show, :list]
  before_action :set_page, only: [:update, :destroy, :show]
  respond_to :json

  def list
    if params.key?(:name)
      @page = Page.friendly.all.includes(:page_template, :page_data_context, :page_translation).where(name:params[:name]).first!
    else
      @page = Page.friendly.all.to_a()
    end
    render json: @page, status: :ok
  end

  def show
    # Nothing to do, JBuilder will be called
  end

  def update
    authorize Page
    begin
      if @page.update(page_params)
        render :show, status: :ok
      else
        render json: @page.errors, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique => rnu
      render json: @page.errors, status: :conflict
    end
  end

  def create
    authorize Page
    begin
      @page = Page.new(page_params)
      if @page.save
        render :show, status: :ok, location: @page
      else
        render json: @page.errors, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique => rnu
      render json: @page.errors, status: :conflict
    end
  end

  def destroy

  end

  private
  def set_page
    @page = Page.friendly.includes(:page_template, :page_data_context, :page_translation).find_by!(name:params[:name])
  end

  def page_params
    params.require(:page).permit(:published, :sort, :name, :version, :icon, :title,
                                 page_template_attributes: [:attachment] ,
                                 page_data_context_attributes: [:attachment],
                                 page_translation_attributes: [:id, :attachment, :_destroy])
  end
end