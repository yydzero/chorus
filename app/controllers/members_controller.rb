class MembersController < ApplicationController
  def index
    workspace = Workspace.find(params[:workspace_id])
    present WorkspaceAccess.members_for(current_user, workspace)
  end

  def create
    workspace = Workspace.find(params[:workspace_id])
    authorize! :administrative_edit, workspace
    # TODO: This next line saves records immediately.  Save does nothing! Validations are ignored.
    workspace.member_ids = params[:member_ids]
    workspace.has_added_member = true
    workspace.save!
    present workspace.reload.members
  end
end