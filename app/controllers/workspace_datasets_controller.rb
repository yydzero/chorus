class WorkspaceDatasetsController < ApplicationController

  def index
    authorize! :show, workspace
    options = {
        :type => params[:type],
        :database_id => params[:database_id],
        :limit => params[:page].to_i * params[:per_page].to_i,
        :sort => [{"lower(relname)" => "asc"}]
    }

    params.merge!(:total_entries => workspace.dataset_count(current_user, options))
    datasets = workspace.datasets(current_user, options).with_name_like(params[:name_pattern]).order("lower(datasets.name)")

    present paginate(datasets), :presenter_options => { :workspace => workspace }
  end

  def create
    authorize! :can_edit_sub_objects, workspace
    datasets = Dataset.where(:id => params[:dataset_ids])

    datasets.each do |dataset|
      if !workspace.has_dataset?(dataset)
        workspace.bound_datasets << dataset
        create_event_for_dataset(dataset, workspace)
      end
    end

    render :json => {}, :status => :created
  end

  def show
    authorize! :show, workspace
    datasets = workspace.datasets(current_user)

    if params[:name]
      dataset = datasets.find_by_name(params[:name])
    else
      dataset =  datasets.find(params[:id])
    end

    present dataset, :presenter_options => { :workspace => workspace }
  end

  def destroy
    authorize! :can_edit_sub_objects, workspace
    dataset = AssociatedDataset.find_by_dataset_id_and_workspace_id(params[:id], params[:workspace_id])
    dataset.destroy
    render :json => {}
  end

  private

  def workspace
    @workspace ||= Workspace.workspaces_for(current_user).find(params[:workspace_id])
  end

  def create_event_for_dataset(dataset, workspace)
    Events::SourceTableCreated.by(current_user).add(
      :dataset => dataset,
      :workspace => workspace
    )
  end
end
