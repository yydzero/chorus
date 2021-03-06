class ColumnController < GpdbController
  def index
    dataset = Dataset.find(params[:dataset_id])
    present paginate GpdbColumn.columns_for(authorized_gpdb_account(dataset), dataset)
  end
end
